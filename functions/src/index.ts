import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {initializeApp} from 'firebase-admin/app';
import {logger} from 'firebase-functions';
import {
  defineInt,
  defineSecret,
  defineString,
} from 'firebase-functions/params';
import {onRequest} from 'firebase-functions/v2/https';

import {requestPaytrIframeToken} from './payments/paytr/paytr_client.ts';
import {createPaytrCallbackHandler} from './payments/paytr/paytr_callback_handler.ts';
import {FirestorePaytrCallbackRepository} from './payments/paytr/paytr_callback_repository.ts';
import {createPaymentSessionHandler} from './payments/paytr/payment_session_handler.ts';
import {createPaymentStatusHandler} from './payments/paytr/payment_status_handler.ts';
import {FirestorePaymentStatusRepository} from './payments/paytr/payment_status_repository.ts';
import {FirestorePaymentSessionRepository} from './payments/paytr/payment_session_repository.ts';
import {paytrContractVersion} from './payments/paytr/payment_types.ts';

initializeApp();

const functionsRegion = defineString('PEA_FUNCTIONS_REGION');
const paytrMerchantId = defineString('PAYTR_MERCHANT_ID');
const paytrMerchantOkUrl = defineString('PAYTR_MERCHANT_OK_URL');
const paytrMerchantFailUrl = defineString('PAYTR_MERCHANT_FAIL_URL');
const paytrLanguage = defineString('PAYTR_LANGUAGE', {default: 'tr'});
const paytrTestMode = defineInt('PAYTR_TEST_MODE', {default: 1});
const paytrDebugOn = defineInt('PAYTR_DEBUG_ON', {default: 1});
const paytrNoInstallment = defineInt('PAYTR_NO_INSTALLMENT', {default: 1});
const paytrMaxInstallment = defineInt('PAYTR_MAX_INSTALLMENT', {default: 0});
const paytrTimeoutLimitMinutes = defineInt('PAYTR_TIMEOUT_LIMIT_MINUTES', {
  default: 30,
});
const paytrRequestTimeoutMilliseconds = defineInt('PAYTR_REQUEST_TIMEOUT_MS', {
  default: 15_000,
});
const paytrMerchantKey = defineSecret('PAYTR_MERCHANT_KEY');
const paytrMerchantSalt = defineSecret('PAYTR_MERCHANT_SALT');

export const paytrBackendHealth = onRequest(
  {
    region: functionsRegion,
    cors: false,
    timeoutSeconds: 10,
    memory: '256MiB',
    maxInstances: 2,
  },
  (request, response) => {
    if (request.method !== 'GET') {
      response.set('Allow', 'GET').status(405).json({
        error: {code: 'method_not_allowed', message: 'Use GET.'},
      });
      return;
    }

    logger.info('PayTR backend health check');
    response.status(200).json({
      status: 'ok',
      service: 'pea-paytr-backend',
      contractVersion: paytrContractVersion,
    });
  },
);

export const paytrApi = onRequest(
  {
    region: functionsRegion,
    cors: false,
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 10,
    concurrency: 20,
    secrets: [paytrMerchantKey, paytrMerchantSalt],
  },
  async (request, response) => {
    if (isPaytrCallbackPath(request.path)) {
      const callbackHandler = createPaytrCallbackHandler({
        repository: new FirestorePaytrCallbackRepository(getFirestore()),
        getMerchantSecrets: () => ({
          merchantKey: paytrMerchantKey.value(),
          merchantSalt: paytrMerchantSalt.value(),
        }),
        logWarning: (message, context) => logger.warn(message, context),
        logError: (message, context) => logger.error(message, context),
      });
      await callbackHandler(request, response);
      return;
    }

    if (isPaymentStatusPath(request.path)) {
      const statusHandler = createPaymentStatusHandler({
        verifyIdToken: async (token) => getAuth().verifyIdToken(token),
        repository: new FirestorePaymentStatusRepository(getFirestore()),
        logError: (message, context) => logger.error(message, context),
      });
      await statusHandler(request, response);
      return;
    }

    if (!isPaymentSessionPath(request.path)) {
      response.status(404).json({
        error: {code: 'not_found', message: 'Payment endpoint not found.'},
      });
      return;
    }

    const repository = new FirestorePaymentSessionRepository(getFirestore());
    const handler = createPaymentSessionHandler({
      verifyIdToken: async (token) => getAuth().verifyIdToken(token),
      repository,
      getGatewayConfig: () => ({
        merchantId: paytrMerchantId.value(),
        merchantKey: paytrMerchantKey.value(),
        merchantSalt: paytrMerchantSalt.value(),
        merchantOkUrl: paytrMerchantOkUrl.value(),
        merchantFailUrl: paytrMerchantFailUrl.value(),
        testMode: readBinaryParameter('PAYTR_TEST_MODE', paytrTestMode.value()),
        debugOn: readBinaryParameter('PAYTR_DEBUG_ON', paytrDebugOn.value()),
        noInstallment: readBinaryParameter(
          'PAYTR_NO_INSTALLMENT',
          paytrNoInstallment.value(),
        ),
        maxInstallment: paytrMaxInstallment.value(),
        timeoutLimitMinutes: paytrTimeoutLimitMinutes.value(),
        requestTimeoutMilliseconds: paytrRequestTimeoutMilliseconds.value(),
        language: readLanguage(paytrLanguage.value()),
      }),
      requestPaytrSession: requestPaytrIframeToken,
      logError: (message, context) => logger.error(message, context),
    });

    await handler(request, response);
  },
);

function isPaytrCallbackPath(path: string): boolean {
  return path === '/payments/paytr/callback' ||
    path === '/payments/paytr/callback/';
}

function isPaymentStatusPath(path: string): boolean {
  return path === '/payments/paytr/status' ||
    path === '/payments/paytr/status/';
}

function isPaymentSessionPath(path: string): boolean {
  return path === '/payments/paytr/session' ||
    path === '/payments/paytr/session/';
}

function readBinaryParameter(name: string, value: number): 0 | 1 {
  if (value !== 0 && value !== 1) {
    throw new Error(`${name} must be 0 or 1.`);
  }
  return value;
}

function readLanguage(value: string): 'tr' | 'en' {
  if (value !== 'tr' && value !== 'en') {
    throw new Error('PAYTR_LANGUAGE must be tr or en.');
  }
  return value;
}
