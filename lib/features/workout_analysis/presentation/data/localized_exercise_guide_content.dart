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
        'An upper-body pushing movement focused on elbow extension on parallel bars.',
    purpose:
        'Uses elbow flexion and extension as the main repetition signal and can flag excessive shoulder extension as a form issue.',
    setupSteps: [
      'Start at the top of parallel bars with your arms extended under control.',
      'Place the camera to the side so the shoulder-elbow-wrist line is visible.',
      'Keep your chest and shoulders in a comfortable position.',
      'Do not force depth if you feel shoulder pain.',
    ],
    tips: [
      'Bend your elbows and lower under control.',
      'Avoid driving your shoulders unnecessarily far backward.',
      'Press upward smoothly from the bottom.',
      'Try to use a consistent depth across repetitions.',
    ],
    commonMistakes: [
      'Forcing the shoulders into excessive depth.',
      'Bouncing without control at the bottom.',
      'Using only a partial elbow range of motion.',
      'Swinging far enough forward or backward to leave the camera frame.',
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
        'Aims to maintain the shoulder-hip-foot line, elbow support, and an extended leg position.',
    setupSteps: [
      'Lie on your side and place your elbow under your shoulder.',
      'Extend your legs and stack your feet or use another balanced foot position.',
      'Place the camera in front of or behind your trunk so the body line is visible.',
      'Lift your hips and create one long line from your shoulder to your ankle.',
    ],
    tips: [
      'Do not let your hips drop toward the floor.',
      'Keep your supporting elbow under your shoulder.',
      'Keep the leg line as long as you comfortably can.',
      'Continue breathing while you hold the position.',
    ],
    commonMistakes: [
      'Letting the hips sag toward the floor.',
      'Placing the elbow too far from the shoulder.',
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
};
