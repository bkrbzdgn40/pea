import '../../domain/models/exercise_type.dart';
import '../models/exercise_guide_content.dart';

ExerciseGuideContent localizedExerciseGuideContent({
  required ExerciseGuideContent content,
  required bool isTurkish,
}) {
  if (isTurkish) {
    return content;
  }

  final copy = _englishCopies[content.type];
  if (copy == null) {
    return content;
  }

  return ExerciseGuideContent(
    type: content.type,
    subtitle: copy.subtitle,
    purpose: copy.purpose,
    difficulty: content.difficulty,
    setupSteps: copy.setupSteps,
    tips: copy.tips,
    commonMistakes: copy.commonMistakes,
    youtubeUrl: content.youtubeUrl,
    youtubeSourceLabel: content.youtubeSourceLabel,
  );
}

class _ExerciseGuideCopy {
  const _ExerciseGuideCopy({
    required this.subtitle,
    required this.purpose,
    required this.setupSteps,
    required this.tips,
    required this.commonMistakes,
  });

  final String subtitle;
  final String purpose;
  final List<String> setupSteps;
  final List<String> tips;
  final List<String> commonMistakes;
}

const _englishCopies = <ExerciseType, _ExerciseGuideCopy>{
  ExerciseType.squat: _ExerciseGuideCopy(
    subtitle:
        'A foundational movement for lower-body strength and knee-hip control.',
    purpose:
        'Trains the legs, hips, and trunk stability together. Controlled depth and consistent alignment take priority.',
    setupSteps: [
      'Place your feet about shoulder-width apart.',
      'Keep your weight balanced through your heels and midfoot.',
      'Keep your chest open and your gaze at a natural level.',
      'Brace your trunk and settle into a balanced position before descending.',
    ],
    tips: [
      'Guide your hips back and down with control.',
      'Let your knees track in line with your feet.',
      'Use a pain-free depth that you can control.',
      'Drive into the floor firmly but smoothly as you stand up.',
    ],
    commonMistakes: [
      'Letting the knees collapse inward.',
      'Lifting the heels off the floor.',
      'Allowing the trunk to fall forward without control.',
      'Dropping quickly and standing up with poor control.',
    ],
  ),
  ExerciseType.plank: _ExerciseGuideCopy(
    subtitle: 'An isometric movement for core endurance and trunk stability.',
    purpose:
        'Builds the ability to keep the trunk stable. Position quality matters more than simply holding for longer.',
    setupSteps: [
      'Align your elbows under your shoulders.',
      'Place your feet about hip-width apart.',
      'Create one long line from your head to your heels.',
      'Settle into position without holding your breath.',
    ],
    tips: [
      'Keep your abdominal and glute muscles gently active.',
      'Do not let your lower back sag.',
      'Keep your shoulders away from your ears.',
      'Take a short rest if your form starts to break down as time increases.',
    ],
    commonMistakes: [
      'Holding the hips too high.',
      'Arching the lower back.',
      'Lifting the neck upward.',
      'Creating unnecessary tension by holding your breath.',
    ],
  ),
  ExerciseType.hollowHold: _ExerciseGuideCopy(
    subtitle:
        'An advanced supine movement for core tension, trunk control, and isometric endurance.',
    purpose:
        'Focuses on maintaining abdominal tension, lifting the shoulders, reaching the arms overhead, and keeping trunk control with the legs extended.',
    setupSteps: [
      'Lie on your back and gently bring your lower back toward the floor.',
      'Engage your abdomen without excessive bracing or flaring your ribs.',
      'Lift your shoulders slightly off the floor and reach your arms overhead.',
      'Raise your legs while keeping the knees extended and the trunk stable.',
    ],
    tips: [
      'If form breaks down, raise your legs or bend your knees slightly.',
      'Reach your arms close to your ears without unnecessarily tensing your neck.',
      'Maintain core tension while continuing to breathe.',
      'Prioritize a clean body position and extended legs instead of forcing a longer hold.',
    ],
    commonMistakes: [
      'Losing lower-back control and relaxing the trunk.',
      'Dropping the shoulders because the arms cannot stay overhead.',
      'Bending the knees and losing the intended leg line.',
      'Lowering the legs farther than you can control.',
    ],
  ),
  ExerciseType.lunge: _ExerciseGuideCopy(
    subtitle:
        'A stationary split-stance movement for single-leg control and lower-body strength.',
    purpose:
        'Trains controlled flexion and extension of the front leg while maintaining balance in a fixed split stance.',
    setupSteps: [
      'Start standing tall and balanced.',
      'Step into a comfortable split stance and keep that stance length fixed.',
      'Keep the leg closest to the camera in front and plant the foot firmly.',
      'Keep your trunk upright and your gaze roughly forward.',
    ],
    tips: [
      'Keep the descent vertical and controlled.',
      'Let the front knee track in line with the foot.',
      'Do not rush as the back knee approaches the floor.',
      'Drive upward without losing balance.',
    ],
    commonMistakes: [
      'Changing foot position between repetitions.',
      'Allowing the front knee to collapse inward.',
      'Letting the trunk tip sideways.',
      'Bouncing quickly and without control from the bottom.',
    ],
  ),
  ExerciseType.pushUp: _ExerciseGuideCopy(
    subtitle:
        'A foundational movement for upper-body strength, core control, and shoulder stability.',
    purpose:
        'Develops pushing strength while challenging shoulder control and whole-body alignment.',
    setupSteps: [
      'Place your hands slightly wider than shoulder-width apart.',
      'Create a straight line from your head to your heels.',
      'Keep your abdomen and glutes active.',
      'Use an elevated surface for an easier variation when needed.',
    ],
    tips: [
      'Control both the descent and the press upward.',
      'Avoid flaring your elbows excessively to the sides.',
      'Keep your body line as your chest approaches the floor.',
      'Adjust your hand position gently if your wrists feel uncomfortable.',
    ],
    commonMistakes: [
      'Letting the hips sag.',
      'Reaching the neck forward.',
      'Flaring the elbows completely out to the sides.',
      'Using rushed, partial repetitions.',
    ],
  ),
  ExerciseType.sitUp: _ExerciseGuideCopy(
    subtitle: 'A controlled core movement based on trunk flexion.',
    purpose:
        'Trains the abdominal muscles dynamically. Control and comfort matter more than repetition count.',
    setupSteps: [
      'Bend your knees and place your feet comfortably on the floor.',
      'Position your hands so they do not pull on your neck.',
      'Use a comfortable, controlled range of motion.',
      'Stop without forcing the movement if your back or neck feels uncomfortable.',
    ],
    tips: [
      'Do not pull your neck as you rise.',
      'Prioritize control over speed.',
      'Lower your trunk back down slowly.',
      'Use a shorter range if you feel discomfort.',
    ],
    commonMistakes: [
      'Pulling the neck with the hands.',
      'Using momentum to rise quickly.',
      'Swinging enough to strain the lower back.',
      'Holding your breath during the movement.',
    ],
  ),
  ExerciseType.bicepsCurl: _ExerciseGuideCopy(
    subtitle:
        'A standing upper-body movement for simultaneous two-arm curl control.',
    purpose:
        'Encourages both arms to move together with control and symmetry. Keeping the elbows close to the trunk and limiting swinging are priorities.',
    setupSteps: [
      'Stand balanced with both arms extended downward at the start.',
      'Make sure both shoulders, elbows, wrists, and hips are clearly visible.',
      'For initial calibration, place the camera directly in front so both arms and hips are visible together.',
      'Prepare to start and finish each repetition with both arms together.',
    ],
    tips: [
      'Curl both arms upward at the same time.',
      'Keep your elbows close to your trunk and relatively still.',
      'Emphasize forearm movement instead of swinging the shoulders or upper arms.',
      'Complete the lowering phase slowly and with control.',
    ],
    commonMistakes: [
      'Raising the arms one at a time or at different speeds.',
      'Flaring the elbows or driving them forward.',
      'Using trunk momentum to swing the weight.',
      'Lowering one arm early while the other remains at the top.',
    ],
  ),
  ExerciseType.lyingLegRaise: _ExerciseGuideCopy(
    subtitle: 'A dynamic supine movement for hip flexion and core control.',
    purpose:
        'Tracks the legs as they rise and lower together while monitoring hip flexion and whether the knees remain extended.',
    setupSteps: [
      'Lie on your back and frame your whole body from the side.',
      'Keep your legs together and your knees comfortably extended.',
      'Start with your legs close to the floor and roughly in line with your trunk.',
      'Reduce the range or stop if you feel lower-back pain.',
    ],
    tips: [
      'Lift both legs together as one controlled unit.',
      'Use a comfortable range without unnecessarily bending your knees.',
      'Control the lowering phase instead of letting gravity take over.',
      'Move only through a range where you can maintain lower-back control.',
    ],
    commonMistakes: [
      'Bending the knees noticeably.',
      'Swinging the legs with momentum.',
      'Letting the lowering phase accelerate without control.',
      'Forcing a larger range despite lower-back discomfort.',
    ],
  ),
  ExerciseType.tricepsDip: _ExerciseGuideCopy(
    subtitle:
        'A triceps-focused bodyweight pushing movement performed from a stable bench or raised surface.',
    purpose:
        'Uses elbow flexion and extension as the main repetition signal and can flag excessive shoulder extension as a form issue.',
    setupSteps: [
      'Place your hands on the edge of a stable, non-slip bench or raised surface behind you.',
      'Move your hips just in front of the bench, place your feet forward, and support your weight through your hands under control.',
      'Place the camera to the side so the shoulder-elbow-wrist line is visible.',
      'Do not force depth if you feel shoulder pain or discomfort.',
    ],
    tips: [
      'Bend your elbows backward and lower under control.',
      'Keep the bottom elbow angle around 90 degrees without forcing unnecessary depth.',
      'Keep your hips close to the bench edge and avoid shrugging or driving the shoulders forward.',
      'Press through your palms and return to the starting position under control.',
    ],
    commonMistakes: [
      'Forcing the shoulders unnecessarily far backward and downward.',
      'Moving the hips too far away from the bench.',
      'Bouncing without control at the bottom.',
      'Using only a partial elbow range of motion.',
    ],
  ),
  ExerciseType.romanianDeadlift: _ExerciseGuideCopy(
    subtitle:
        'A dynamic strength movement for the hip hinge and posterior-chain control.',
    purpose:
        'Tracks the primary movement through the hip angle and uses a relatively stable knee angle as a form signal.',
    setupSteps: [
      'Stand tall and place the camera directly to your side.',
      'Bend your knees slightly and keep that angle mostly stable throughout the movement.',
      'Send your hips backward and hinge your trunk from the hips.',
      'Keep the load close to your legs.',
    ],
    tips: [
      'Initiate the movement from the hips rather than the knees.',
      'Avoid noticeably increasing knee bend during the repetition.',
      'Turn around at a hip-flexion depth you can control.',
      'Drive the hips forward and finish the trunk position as you rise.',
    ],
    commonMistakes: [
      'Turning the movement into a squat by bending the knees too much.',
      'Letting the load drift away from the body.',
      'Losing lower-back position to force a deeper bottom position.',
      'Bending only through the trunk instead of using a hip hinge.',
    ],
  ),
  ExerciseType.goodMorning: _ExerciseGuideCopy(
    subtitle:
        'A controlled standing strength movement for the hip hinge and posterior chain.',
    purpose:
        'Tracks the primary movement through the hip angle and uses a relatively stable knee angle as a form signal.',
    setupSteps: [
      'Stand tall and place the camera directly to your side.',
      'Set your feet about hip-width apart and keep a soft bend in your knees.',
      'Place your hands comfortably across your chest or behind your head.',
      'Brace your trunk and settle your balance before sending the hips backward.',
    ],
    tips: [
      'Initiate the movement by sending the hips backward rather than bending the knees.',
      'Keep your knee angle mostly stable throughout the repetition.',
      'Turn around at a controlled depth where you can maintain trunk alignment.',
      'Drive the hips forward and finish in a tall position as you rise.',
    ],
    commonMistakes: [
      'Turning the movement into a squat by bending the knees too much.',
      'Rounding through the lower back instead of using a controlled hip hinge.',
      'Losing trunk alignment to force a deeper range of motion.',
      'Ending the repetition before fully returning the hips to standing.',
    ],
  ),
  ExerciseType.lateralRaise: _ExerciseGuideCopy(
    subtitle: 'A controlled two-arm raising movement for shoulder abduction.',
    purpose:
        'Tracks both arms as they raise to the sides, using shoulder angle as the primary signal and elbow extension as a form signal.',
    setupSteps: [
      'Face the camera and keep both shoulder-elbow-wrist lines in frame.',
      'Start with your arms relaxed at your sides.',
      'Keep your elbows soft but mostly extended without locking them.',
      'Prepare to move both arms at the same time.',
    ],
    tips: [
      'Raise both arms to the sides with control.',
      'Turn around near shoulder height without forcing unnecessary height.',
      'Keep your elbow angle mostly consistent throughout the repetition.',
      'Lower with control instead of swinging the load.',
    ],
    commonMistakes: [
      'Shortening the movement by bending the elbows substantially.',
      'Swinging the arms far above shoulder height.',
      'Using momentum from the trunk.',
      'Moving the two arms at different speeds.',
    ],
  ),
  ExerciseType.shoulderPress: _ExerciseGuideCopy(
    subtitle:
        'An elbow-extension-focused movement for a simultaneous two-arm overhead press.',
    purpose:
        'Uses both elbows extending together as the primary repetition signal and counts a controlled press-and-return cycle.',
    setupSteps: [
      'Face the camera and keep both shoulder-elbow-wrist lines in frame.',
      'Begin with your elbows comfortably bent in the lower position.',
      'Prepare to press both arms upward at the same time.',
      'Keep your head and trunk relatively still instead of adding unnecessary movement.',
    ],
    tips: [
      'Press both arms upward together.',
      'Extend your elbows with control at the top.',
      'Return slowly to the starting position.',
      'Use the same lower position between repetitions.',
    ],
    commonMistakes: [
      'Pressing the arms at different times.',
      'Using only a partial elbow range of motion.',
      'Dropping the load without control.',
      'Using obvious trunk swinging for momentum.',
    ],
  ),
  ExerciseType.calfRaise: _ExerciseGuideCopy(
    subtitle:
        'A controlled repetition movement for calf strength and ankle plantar flexion.',
    purpose:
        'Tracks the heel raise-and-lower cycle while aiming to keep the knee line mostly stable throughout the movement.',
    setupSteps: [
      'Place the camera to the side so the hip-knee-ankle-foot line is visible.',
      'Keep your feet in a comfortable, balanced position.',
      'Start with the knees mostly extended without locking them.',
      'Prepare to raise both heels together with control.',
    ],
    tips: [
      'Maintain balance over the balls of your feet as the heels rise.',
      'Avoid escaping the movement by bending the knees noticeably.',
      'Pause briefly and with control at the top.',
      'Control the descent instead of dropping with gravity.',
    ],
    commonMistakes: [
      'Bouncing through the knees.',
      'Raising the heels only slightly.',
      'Losing balance at the top.',
      'Dropping down without control.',
    ],
  ),
  ExerciseType.frontRaise: _ExerciseGuideCopy(
    subtitle: 'A controlled forward arm raise for shoulder flexion.',
    purpose:
        'Tracks the arm as it rises forward while monitoring whether the elbow remains mostly extended.',
    setupSteps: [
      'Place the camera to the side so the shoulder-elbow-wrist and hip line are visible.',
      'Start with your arms relaxed beside your trunk.',
      'Keep your elbows mostly extended without locking them.',
      'Prepare to raise the arm forward without swinging your trunk.',
    ],
    tips: [
      'Raise the arm forward with control.',
      'Turn around near shoulder height without forcing unnecessary height.',
      'Keep your elbow angle mostly consistent throughout the repetition.',
      'Complete the lowering phase slowly.',
    ],
    commonMistakes: [
      'Bending the elbow substantially.',
      'Swinging the trunk backward.',
      'Throwing the arm upward without control.',
      'Letting the arm drop quickly on the way down.',
    ],
  ),
  ExerciseType.gluteBridge: _ExerciseGuideCopy(
    subtitle:
        'A floor-based movement for hip extension and posterior-chain control.',
    purpose:
        'Uses opening of the shoulder-hip-knee line as the primary repetition signal and counts controlled bridge cycles.',
    setupSteps: [
      'Lie on your back and place the camera directly to your side.',
      'Bend your knees and plant your feet evenly on the floor.',
      'Make sure your shoulder, hip, knee, and ankle are visible in frame.',
      'Prepare to lift your hips with control.',
    ],
    tips: [
      'Open the trunk position smoothly as you drive the hips upward.',
      'Avoid excessively arching your lower back at the top.',
      'Keep your feet still throughout the movement.',
      'Lower back down with control.',
    ],
    commonMistakes: [
      'Overarching through the lower back.',
      'Using partial repetitions without raising the hips enough.',
      'Sliding the feet between repetitions.',
      'Dropping down without control.',
    ],
  ),
  ExerciseType.wallSit: _ExerciseGuideCopy(
    subtitle:
        'An isometric lower-body movement based on holding the knee and hip angles steady.',
    purpose:
        'Aims to maintain controlled knee depth, hip position, and an upright trunk line during a wall sit.',
    setupSteps: [
      'Place your back against a wall and position the camera to your side.',
      'Move your feet a comfortable distance away from the wall.',
      'Bend your knees under control and lower into the hold position.',
      'Keep your head, shoulder, hip, knee, and ankle visible in frame.',
    ],
    tips: [
      'Hold your knee angle within a comfortable, controlled range.',
      'Keep your trunk upright and close to the wall line.',
      'Keep the soles of your feet balanced on the floor.',
      'Exit the position instead of forcing more time once your form breaks down.',
    ],
    commonMistakes: [
      'Staying too high to meaningfully challenge the position.',
      'Dropping too deep to maintain the position.',
      'Folding the trunk forward.',
      'Sliding the feet during the hold.',
    ],
  ),
  ExerciseType.sidePlank: _ExerciseGuideCopy(
    subtitle:
        'An isometric movement for lateral trunk endurance and core stability.',
    purpose:
        'Aims to maintain the shoulder-hip-foot line, stable forearm or straight-arm support, and an extended leg position.',
    setupSteps: [
      'Lie on your side; place your elbow under your shoulder for forearm support or your hand under your shoulder for straight-arm support.',
      'Extend your legs and stack your feet or use another balanced foot position.',
      'Place the camera in front of or behind your trunk so the body line is visible.',
      'Lift your hips and create one long line from your shoulder to your ankle.',
    ],
    tips: [
      'Do not let your hips drop toward the floor.',
      'Keep your forearm or straight-arm support stable under your shoulder.',
      'Keep the leg line as long as you comfortably can.',
      'Continue breathing while you hold the position.',
    ],
    commonMistakes: [
      'Letting the hips sag toward the floor.',
      'Placing the supporting elbow or hand too far from the shoulder line.',
      'Bending the knees substantially.',
      'Rotating the trunk forward or backward.',
    ],
  ),
  ExerciseType.jumpingJack: _ExerciseGuideCopy(
    subtitle:
        'A dynamic full-body movement in which the arms and legs open and close together.',
    purpose:
        'Uses both arms rising together as the primary repetition signal and leg abduction as a supporting form signal.',
    setupSteps: [
      'Face the camera and keep your whole body in frame.',
      'Start with your feet close together and your arms at your sides.',
      'Make sure both arms and both legs are clearly visible.',
      'Prepare to open and close your arms and legs in the same cycle.',
    ],
    tips: [
      'Open the arms and legs at the same time.',
      'Raise the arms high enough at the top.',
      'Do not mimic the movement with the arms while barely moving the legs.',
      'Keep landings soft and rhythmic.',
    ],
    commonMistakes: [
      'Moving only the arms.',
      'Raising the arms at different speeds.',
      'Landing the feet hard and without control.',
      'Rushing through partial-range repetitions.',
    ],
  ),
  ExerciseType.crunch: _ExerciseGuideCopy(
    subtitle:
        'A short trunk-flexion movement that lifts the shoulders from the floor under control.',
    purpose:
        'Tracks controlled closing of the shoulder-hip line and counts repetitions through a shorter range than a full sit-up.',
    setupSteps: [
      'Lie on your back, bend your knees, and plant your feet on the floor.',
      'Place the camera to the side so the shoulder-hip-knee line is visible.',
      'Keep your neck relaxed and place your hands without pulling your head.',
      'Wait in the neutral position, ready to lift your shoulders with control.',
    ],
    tips: [
      'Lift your shoulders and curl your trunk through a short controlled range.',
      'Use your core without forcing your lower back off the floor.',
      'Change direction at the top without swinging.',
      'Do not let gravity control the return.',
    ],
    commonMistakes: [
      'Pulling the neck forward with the hands.',
      'Swinging through the movement quickly.',
      'Using partial repetitions without lifting the shoulders enough.',
      'Dropping back to the floor without control.',
    ],
  ),
  ExerciseType.reverseCrunch: _ExerciseGuideCopy(
    subtitle:
        'A core movement that lifts the hips from the floor with control.',
    purpose:
        'Tracks closing of the shoulder-hip-knee angle to count controlled hip-curl cycles.',
    setupSteps: [
      'Lie on your back and bend your knees comfortably.',
      'Place the camera to the side so the shoulder-hip-knee line is visible.',
      'Keep your arms at your sides for balance and stabilize your trunk.',
      'Settle your knees slightly beyond your hips, ready for a controlled curl.',
    ],
    tips: [
      'Curl your hips with control instead of swinging your knees.',
      'Use a small, clean hip lift at the top.',
      'Avoid excessive range that causes lower-back discomfort.',
      'Return to the starting position slowly.',
    ],
    commonMistakes: [
      'Swinging the legs with momentum.',
      'Moving only the knees without lifting the hips.',
      'Losing control at the top.',
      'Dropping through the return.',
    ],
  ),
  ExerciseType.bentKneeLegRaise: _ExerciseGuideCopy(
    subtitle:
        'A controlled hip-flexion and core movement performed with the knees bent.',
    purpose:
        'Uses the shoulder-hip-knee angle to track the bent legs lifting and lowering as a repetition cycle.',
    setupSteps: [
      'Lie on your back, bend your knees comfortably, and keep your legs together.',
      'Place the camera to the side so the shoulder, hip, knee, and ankle are visible.',
      'Keep your arms at your sides for balance.',
      'Start with the legs low without forcing your lower back.',
    ],
    tips: [
      'Raise both legs together with control.',
      'Keep your knee angle approximately consistent throughout the movement.',
      'Do not lower past the point where you lose lower-back control.',
      'Complete the lowering phase slowly.',
    ],
    commonMistakes: [
      'Swinging the legs.',
      'Changing the knee angle continuously through the repetition.',
      'Lowering too far and losing lower-back control.',
      'Dropping quickly into the start position.',
    ],
  ),
  ExerciseType.standingHamstringCurl: _ExerciseGuideCopy(
    subtitle:
        'A standing unilateral knee-flexion movement for hamstring control.',
    purpose:
        'Tracks the hip-knee-ankle angle as the heel curls toward the glutes and returns to extension.',
    setupSteps: [
      'Stand side-on to the camera with the working leg closest to it.',
      'Shift your weight onto the support leg in a balanced position.',
      'Use light support from a stable surface if needed.',
      'Begin with the working knee extended and the hips steady.',
    ],
    tips: [
      'Curl your heel toward your glutes with control.',
      'Keep the thigh as still as possible instead of moving the knee forward.',
      'Do not swing your trunk forward or backward.',
      'Extend the leg back to the starting position with control.',
    ],
    commonMistakes: [
      'Folding forward at the hips.',
      'Moving the knee forward to imitate a larger range.',
      'Losing balance on the support leg.',
      'Letting the leg drop without control.',
    ],
  ),
  ExerciseType.standingHipAbduction: _ExerciseGuideCopy(
    subtitle: 'A standing unilateral lateral leg raise for hip control.',
    purpose:
        'Uses the shoulder-hip-knee angle as the repetition signal and knee extension as a supporting form signal.',
    setupSteps: [
      'Face the camera and keep your whole body in frame.',
      'Shift your weight onto the support leg and keep your trunk upright.',
      'Relax your arms at your sides or use light support from a stable surface.',
      'Begin with the working knee extended in the neutral position.',
    ],
    tips: [
      'Raise the leg to the side without leaning your trunk away.',
      'Keep the working knee as straight as possible.',
      'Keep the foot naturally aligned and the hips facing forward.',
      'Lower the leg back to the start with control.',
    ],
    commonMistakes: [
      'Leaning the trunk to exaggerate the range.',
      'Bending the working knee substantially.',
      'Rotating the hips outward.',
      'Swinging the leg without control.',
    ],
  ),
  ExerciseType.overheadTricepsExtension: _ExerciseGuideCopy(
    subtitle:
        'A bilateral overhead elbow-extension movement performed with both arms together.',
    purpose:
        'Tracks both elbows extending together as the repetition signal and upper-arm position as a form signal.',
    setupSteps: [
      'Face the camera and keep your head, shoulders, elbows, and wrists in frame.',
      'Bring your arms overhead and bend your elbows comfortably.',
      'Keep your upper arms close to your head and your trunk upright.',
      'Prepare to move both arms at the same time.',
    ],
    tips: [
      'Extend both elbows together with control.',
      'Keep your upper arms steady instead of swinging them forward and back.',
      'Do not forcefully lock the elbows at the top.',
      'Lower the weight behind your head with control.',
    ],
    commonMistakes: [
      'Letting the upper arms flare widely.',
      'Moving the arms at different times.',
      'Leaning excessively backward through the lower back.',
      'Dropping the weight quickly.',
    ],
  ),
  ExerciseType.uprightRow: _ExerciseGuideCopy(
    subtitle:
        'A simultaneous two-arm pulling movement led upward by the elbows.',
    purpose:
        'Tracks both shoulder angles increasing together to count controlled upward pulls and returns.',
    setupSteps: [
      'Face the camera and keep both shoulder-elbow-wrist lines in frame.',
      'Start with your arms down in front of your body.',
      'Keep your shoulders relaxed and your trunk upright.',
      'Prepare to guide both elbows upward at the same time.',
    ],
    tips: [
      'Lead the pull with your elbows rather than your hands.',
      'Do not force the elbows unnecessarily above shoulder height.',
      'Move both arms together without swinging the trunk.',
      'Complete the return under control.',
    ],
    commonMistakes: [
      'Shrugging the shoulders excessively toward the ears.',
      'Using trunk momentum to swing the load.',
      'Pulling the arms to different heights.',
      'Lowering the load without control.',
    ],
  ),
  ExerciseType.standingHipExtension: _ExerciseGuideCopy(
    subtitle:
        'A standing unilateral hip-extension movement for posterior-chain control.',
    purpose:
        'Uses the shoulder-hip-knee angle to track the straight working leg moving backward and returning to neutral.',
    setupSteps: [
      'Stand side-on with the working leg closest to the camera.',
      'Shift your weight evenly onto the support leg.',
      'Begin with the working knee extended and the trunk upright.',
      'Use light support from a stable surface if needed.',
    ],
    tips: [
      'Move the leg backward from the hip with control.',
      'Avoid excessively arching your lower back.',
      'Keep the working knee as straight as possible.',
      'Return the leg to the start with control.',
    ],
    commonMistakes: [
      'Leaning the trunk forward to exaggerate the movement.',
      'Arching excessively through the lower back.',
      'Bending the working knee substantially.',
      'Swinging the leg without control.',
    ],
  ),
  ExerciseType.standingKneeRaise: _ExerciseGuideCopy(
    subtitle: 'A standing unilateral knee raise for hip flexion and balance.',
    purpose:
        'Tracks the closing hip angle while checking that the working knee bends during each controlled raise.',
    setupSteps: [
      'Stand side-on with the working leg closest to the camera.',
      'Keep your trunk upright and your support foot balanced.',
      'Begin with the working leg extended.',
      'Use light support if necessary.',
    ],
    tips: [
      'Raise your knee toward your torso with control.',
      'Bend the knee comfortably during the lift.',
      'Move from the hip without leaning backward.',
      'Return the foot to the floor with control.',
    ],
    commonMistakes: [
      'Leaning the trunk backward.',
      'Keeping the knee too straight and turning it into a leg raise.',
      'Losing balance on the support foot.',
      'Dropping the leg quickly.',
    ],
  ),
  ExerciseType.standingStraightLegRaise: _ExerciseGuideCopy(
    subtitle: 'A standing hip-flexion movement performed with a straight leg.',
    purpose:
        'Tracks forward leg raises through the hip angle while the working knee remains extended.',
    setupSteps: [
      'Stand side-on with the working leg closest to the camera.',
      'Shift your weight onto the support leg.',
      'Keep the working knee extended and the foot neutral.',
      'Begin upright and balanced.',
    ],
    tips: [
      'Raise the leg forward with control.',
      'Keep the working knee extended throughout the movement.',
      'Do not lean backward to gain extra range.',
      'Lower the leg slowly to the start.',
    ],
    commonMistakes: [
      'Bending the working knee.',
      'Leaning the trunk backward.',
      'Swinging the leg with momentum.',
      'Dropping the leg without control.',
    ],
  ),
  ExerciseType.vUp: _ExerciseGuideCopy(
    subtitle:
        'An advanced core movement in which the trunk and straight legs rise together.',
    purpose:
        'Uses the closing shoulder-hip-knee angle to track controlled V-shaped repetition cycles.',
    setupSteps: [
      'Lie on your back with your legs together and knees extended.',
      'Reach your arms overhead to create a long starting line.',
      'Position the camera side-on so the shoulder-hip-knee line is visible.',
      'Settle into the long starting position without straining your lower back.',
    ],
    tips: [
      'Raise your trunk and legs together.',
      'Keep your knees as straight as possible.',
      'Reach the top without swinging.',
      'Lower back down slowly and under control.',
    ],
    commonMistakes: [
      'Raising only the legs or only the trunk.',
      'Bending the knees substantially.',
      'Using momentum to swing upward.',
      'Dropping back to the start without control.',
    ],
  ),
  ExerciseType.frogPump: _ExerciseGuideCopy(
    subtitle:
        'A short-range hip-extension movement performed with the soles together and knees opened outward.',
    purpose:
        'Tracks the hips lifting and lowering under control while the legs remain in the frog position.',
    setupSteps: [
      'Lie on your back and bend your knees.',
      'Bring the soles of your feet together and open your knees outward.',
      'Rest your arms comfortably beside your body.',
      'Place the camera side-on so the hip line is visible.',
    ],
    tips: [
      'Raise your hips with control.',
      'Squeeze at the top without excessively arching your lower back.',
      'Keep the soles of your feet together.',
      'Lower your hips with control.',
    ],
    commonMistakes: [
      'Arching excessively through the lower back.',
      'Separating the soles of the feet.',
      'Using only a very small partial lift.',
      'Dropping the hips without control.',
    ],
  ),
  ExerciseType.lyingTricepsExtension: _ExerciseGuideCopy(
    subtitle:
        'A controlled elbow-extension movement performed lying on the floor.',
    purpose:
        'Tracks the elbow closest to the camera extending from a bent position and returning with control.',
    setupSteps: [
      'Lie on your back, bend your knees, and plant your feet.',
      'Place the camera side-on so the shoulder-elbow-wrist line is visible.',
      'Keep your upper arm positioned above the shoulder.',
      'Bend the elbow so your hand starts near your head.',
    ],
    tips: [
      'Extend the elbow with control.',
      'Keep the upper arm steady instead of swinging at the shoulder.',
      'Do not forcefully lock the elbow at the top.',
      'Lower your hand toward your head with control.',
    ],
    commonMistakes: [
      'Moving the upper arm from the shoulder.',
      'Letting the elbow flare away.',
      'Dropping the weight quickly toward the head.',
      'Stopping at a partial extension.',
    ],
  ),
  ExerciseType.floorChestPress: _ExerciseGuideCopy(
    subtitle: 'A controlled chest-press movement performed lying on the floor.',
    purpose:
        'Tracks the elbow closest to the camera extending from a bent position and returning near the floor.',
    setupSteps: [
      'Lie on your back, bend your knees, and plant your feet.',
      'Place the camera side-on so the shoulder-elbow-wrist line is visible.',
      'Bend the elbow to roughly a right angle with the upper arm near the floor.',
      'Keep the wrist balanced above the elbow.',
    ],
    tips: [
      'Press the arm upward with control.',
      'Avoid lifting the shoulder unnecessarily from the floor.',
      'Do not forcefully lock the elbow at the top.',
      'Lower the elbow toward the floor with control.',
    ],
    commonMistakes: [
      'Lifting the shoulder forward.',
      'Bending the wrist excessively backward.',
      'Dropping the elbow onto the floor.',
      'Stopping before reaching a full press.',
    ],
  ),
  ExerciseType.yRaise: _ExerciseGuideCopy(
    subtitle:
        'A shoulder-control movement that raises both arms diagonally into a Y shape.',
    purpose:
        'Tracks both arms rising together into the Y line while using elbow extension as a form signal.',
    setupSteps: [
      'Face the camera and keep your upper body in frame.',
      'Begin with your arms down by your sides.',
      'Keep your elbows softly extended and your arms long.',
      'Set your trunk upright and keep your shoulders relaxed.',
    ],
    tips: [
      'Raise both arms diagonally to form a wide Y.',
      'Move both arms at the same speed.',
      'Maintain your elbow angle throughout the movement.',
      'Lower the arms back to the start with control.',
    ],
    commonMistakes: [
      'Bending the elbows substantially.',
      'Raising the arms to different heights.',
      'Shrugging the shoulders toward the ears.',
      'Swinging the trunk backward.',
    ],
  ),
};
