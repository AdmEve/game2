/// Rules for the offline party mode: two teams, one phone passed around.
/// The drawer draws (or acts out) the word; their team shouts guesses; the
/// phone holder taps whether they got it. Scoring matches online games:
/// 100–300 by time left, and a flat 75 for the other team's steal.
library;

enum PartyMode { draw, mime }

enum PartyStage { pass, choose, play, steal, result, over }

const stealSeconds = 10;
const stealPoints = 75;

int partyGuessPoints(int secondsLeft, int turnSeconds) =>
    (100 + (secondsLeft.clamp(0, turnSeconds) / turnSeconds) * 200).round();

class TurnOutcome {
  const TurnOutcome({required this.word, required this.team, required this.points, required this.byTeam});
  final String word;
  final int team; // the team whose turn it was
  final int points;
  final int? byTeam; // who scored: the drawing team, the stealing team, or nobody
}

class PartyGame {
  PartyGame({required this.teams, required this.turnsPerTeam, required this.turnSeconds, required this.mode})
      : assert(teams.length == 2);

  final List<String> teams;
  final int turnsPerTeam;
  final int turnSeconds;
  final PartyMode mode;

  final List<int> scores = [0, 0];
  int turnIndex = 0;
  PartyStage stage = PartyStage.pass;
  List<String> choices = const [];
  String? word;
  bool reshuffled = false;
  int wordsGuessed = 0;
  TurnOutcome? last;

  int get totalTurns => teams.length * turnsPerTeam;
  int get team => turnIndex % teams.length;
  int get otherTeam => 1 - team;
  int get round => turnIndex ~/ teams.length + 1;
  int? get winner => scores[0] == scores[1] ? null : (scores[0] > scores[1] ? 0 : 1);

  /// The drawer has the phone: offer words.
  void offer(List<String> words) {
    assert(stage == PartyStage.pass || stage == PartyStage.choose);
    choices = words;
    stage = PartyStage.choose;
  }

  /// Swap the offered words once per turn.
  bool get canReshuffle => !reshuffled;
  void reshuffle(List<String> words) {
    if (reshuffled) return;
    reshuffled = true;
    choices = words;
  }

  void pick(int i) {
    assert(stage == PartyStage.choose);
    word = choices[i];
    stage = PartyStage.play;
  }

  /// The drawing team got it with [secondsLeft] on the clock.
  int solved(int secondsLeft) {
    assert(stage == PartyStage.play);
    final pts = partyGuessPoints(secondsLeft, turnSeconds);
    scores[team] += pts;
    wordsGuessed++;
    last = TurnOutcome(word: word!, team: team, points: pts, byTeam: team);
    stage = PartyStage.result;
    return pts;
  }

  /// Time ran out or the team gave up: the other team may steal.
  void openSteal() {
    assert(stage == PartyStage.play);
    stage = PartyStage.steal;
  }

  int stealResult(bool stolen) {
    assert(stage == PartyStage.steal);
    final pts = stolen ? stealPoints : 0;
    scores[otherTeam] += pts;
    if (stolen) wordsGuessed++;
    last = TurnOutcome(word: word!, team: team, points: pts, byTeam: stolen ? otherTeam : null);
    stage = PartyStage.result;
    return pts;
  }

  void next() {
    assert(stage == PartyStage.result);
    turnIndex++;
    word = null;
    choices = const [];
    reshuffled = false;
    stage = turnIndex >= totalTurns ? PartyStage.over : PartyStage.pass;
  }
}
