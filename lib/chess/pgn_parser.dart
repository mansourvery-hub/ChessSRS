import 'dart:convert';

/// A single tag-pair header from a PGN game.
class PgnHeader {
  const PgnHeader(this.key, this.value);
  final String key;
  final String value;
}

/// Abstract base class for PGN movetext tokens.
abstract class PgnToken {
  const PgnToken();
}

class MoveToken extends PgnToken {
  const MoveToken(this.san);
  final String san;
  @override
  String toString() => 'Move($san)';
}

class CommentToken extends PgnToken {
  const CommentToken(this.comment);
  final String comment;
  @override
  String toString() => 'Comment($comment)';
}

class ParenOpenToken extends PgnToken {
  const ParenOpenToken();
  @override
  String toString() => '(';
}

class ParenCloseToken extends PgnToken {
  const ParenCloseToken();
  @override
  String toString() => ')';
}

class NagToken extends PgnToken {
  const NagToken(this.value);
  final int value;
  @override
  String toString() => '\$$value';
}

class ResultToken extends PgnToken {
  const ResultToken(this.result);
  final String result;
  @override
  String toString() => 'Result($result)';
}

/// A parsed PGN game before validation and domain conversion.
class RawPgnGame {
  const RawPgnGame({
    required this.headers,
    required this.movetext,
  });

  final Map<String, String> headers;
  final String movetext;

  @override
  String toString() => 'RawPgnGame(headers: $headers, movetext: $movetext)';
}

/// Represents a recursive move variation tree parsed from a PGN.
class PgnNode {
  PgnNode(
    this.san, {
    List<PgnNode>? children,
    this.comment,
    this.nag,
  }) : children = children ?? [];

  final String san;
  String? comment;
  int? nag;
  final List<PgnNode> children;

  @override
  String toString() {
    return 'PgnNode($san, children: ${children.length}, comment: $comment)';
  }
}

class PgnParser {
  const PgnParser();

  /// Split multiple games/chapters in PGN text and extract raw headers/movetext.
  List<RawPgnGame> splitGames(String pgnText) {
    final games = <RawPgnGame>[];
    final lines = LineSplitter.split(pgnText).toList();

    var headers = <String, String>{};
    var movetextBuffer = StringBuffer();
    var inHeader = true;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (headers.isNotEmpty) {
          inHeader = false;
        }
        continue;
      }

      if (trimmed.startsWith('[')) {
        if (!inHeader) {
          // We were in movetext, and now hit a new header. This means the
          // previous game has finished. Commit it!
          games.add(RawPgnGame(
            headers: headers,
            movetext: movetextBuffer.toString().trim(),
          ));
          headers = <String, String>{};
          movetextBuffer = StringBuffer();
          inHeader = true;
        }

        // Parse header tag [Key "Value"]
        final match = RegExp(r'^\[([A-Za-z0-9_]+)\s+"(.*)"\]$').firstMatch(trimmed);
        if (match != null) {
          final key = match.group(1)!;
          final val = match.group(2)!;
          headers[key] = val;
        }
      } else {
        inHeader = false;
        movetextBuffer.writeln(trimmed);
      }
    }

    if (headers.isNotEmpty || movetextBuffer.isNotEmpty) {
      games.add(RawPgnGame(
        headers: headers,
        movetext: movetextBuffer.toString().trim(),
      ));
    }

    return games;
  }

  /// Tokenize PGN movetext string.
  List<PgnToken> tokenize(String movetext) {
    final tokens = <PgnToken>[];
    var i = 0;
    final len = movetext.length;

    while (i < len) {
      final char = movetext[i];

      // Skip whitespace
      if (char == ' ' || char == '\t' || char == '\n' || char == '\r') {
        i++;
        continue;
      }

      // Line comment ;
      if (char == ';') {
        final start = i + 1;
        while (i < len && movetext[i] != '\n' && movetext[i] != '\r') {
          i++;
        }
        tokens.add(CommentToken(movetext.substring(start, i).trim()));
        continue;
      }

      // Bracket comment {}
      if (char == '{') {
        final start = i + 1;
        while (i < len && movetext[i] != '}') {
          i++;
        }
        if (i < len) {
          tokens.add(CommentToken(movetext.substring(start, i).trim()));
          i++; // Skip closing }
        } else {
          tokens.add(CommentToken(movetext.substring(start).trim()));
        }
        continue;
      }

      // RAV parens
      if (char == '(') {
        tokens.add(const ParenOpenToken());
        i++;
        continue;
      }
      if (char == ')') {
        tokens.add(const ParenCloseToken());
        i++;
        continue;
      }

      // NAG
      if (char == '\$') {
        i++;
        var nagVal = 0;
        while (i < len && _isDigit(movetext[i])) {
          nagVal = nagVal * 10 + (movetext.codeUnitAt(i) - 48);
          i++;
        }
        tokens.add(NagToken(nagVal));
        continue;
      }

      // General word (SAN, move number, or result)
      final start = i;
      while (i < len &&
          movetext[i] != ' ' &&
          movetext[i] != '\t' &&
          movetext[i] != '\n' &&
          movetext[i] != '\r' &&
          movetext[i] != '(' &&
          movetext[i] != ')' &&
          movetext[i] != '{' &&
          movetext[i] != '}' &&
          movetext[i] != ';') {
        i++;
      }
      final word = movetext.substring(start, i);

      // Ignore standard move numbers like "1.", "12...", and split
      // concatenated tokens like "1.e4" or "12...c5" into number + SAN.
      final moveNumber = RegExp(r'^(\d+)\.+(.*)$').firstMatch(word);
      if (moveNumber != null) {
        final rest = moveNumber.group(2)!;
        if (rest.isEmpty) continue;
        final san = rest.replaceAll(RegExp(r'[?!]+$'), '');
        if (san.isNotEmpty) {
          tokens.add(MoveToken(san));
        }
        continue;
      }

      // Game results
      if (word == '1-0' || word == '0-1' || word == '1/2-1/2' || word == '*') {
        tokens.add(ResultToken(word));
        continue;
      }

      // SAN move
      // Strip trailing decorations like ?, !, ?!
      final san = word.replaceAll(RegExp(r'[?!]+$'), '');
      if (san.isNotEmpty) {
        tokens.add(MoveToken(san));
      }
    }

    return tokens;
  }

  bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  /// Parse list of tokens into a recursive tree of PgnNodes under a dummy root.
  PgnNode parseTokens(List<PgnToken> tokens) {
    final root = PgnNode('');
    var index = 0;
    _parseSequence(tokens, () => index, (val) => index = val, [root]);
    return root;
  }

  void _parseSequence(
    List<PgnToken> tokens,
    int Function() getIndex,
    void Function(int) setIndex,
    List<PgnNode> path,
  ) {
    // We keep a local path for this branch. We copy the outer path so that
    // mutations within this sequence don't affect parent/sibling sequences.
    final localPath = List<PgnNode>.from(path);

    while (getIndex() < tokens.length) {
      final token = tokens[getIndex()];

      if (token is ParenCloseToken) {
        setIndex(getIndex() + 1);
        return; // End of recursive variation
      }

      if (token is ParenOpenToken) {
        setIndex(getIndex() + 1);
        // A variation branches off from the node BEFORE the last created move.
        // That is localPath[localPath.length - 2].
        // If there are no moves created in localPath yet (only root), attach to root.
        final attachPath = localPath.length > 1
            ? localPath.sublist(0, localPath.length - 1)
            : [localPath.last];
        _parseSequence(tokens, getIndex, setIndex, attachPath);
        continue;
      }

      if (token is MoveToken) {
        final node = PgnNode(token.san);
        localPath.last.children.add(node);
        localPath.add(node);
        setIndex(getIndex() + 1);
        continue;
      }

      if (token is CommentToken) {
        if (localPath.length > 1) {
          localPath.last.comment = token.comment;
        } else {
          localPath.last.comment = token.comment;
        }
        setIndex(getIndex() + 1);
        continue;
      }

      if (token is NagToken) {
        if (localPath.length > 1) {
          localPath.last.nag = token.value;
        }
        setIndex(getIndex() + 1);
        continue;
      }

      if (token is ResultToken) {
        setIndex(getIndex() + 1);
        continue;
      }

      // Fallback for unexpected tokens
      setIndex(getIndex() + 1);
    }
  }
}