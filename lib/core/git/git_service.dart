import 'dart:io';
import 'package:devspace/core/logging/log.dart';
import 'package:devspace/core/model/models.dart';

class GitService {
  const GitService._();

  static const String _tag = 'git';

  static Future<GitRepoStatus> checkStatus(String projectPath) async {
    try {
      final dir = Directory(projectPath);
      if (!dir.existsSync()) {
        return GitRepoStatus.empty();
      }

      // Check if it's a git repo
      final isRepoResult = await Process.run(
        'git',
        ['rev-parse', '--is-inside-work-tree'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 4));

      if (isRepoResult.exitCode != 0 ||
          isRepoResult.stdout.toString().trim() != 'true') {
        return GitRepoStatus.empty();
      }

      // 1. Get current branch
      var branch = '';
      final branchResult = await Process.run(
        'git',
        ['branch', '--show-current'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 4));

      branch = branchResult.stdout.toString().trim();
      if (branch.isEmpty) {
        // Might be in detached HEAD state
        final headResult = await Process.run(
          'git',
          ['rev-parse', '--short', 'HEAD'],
          workingDirectory: projectPath,
        ).timeout(const Duration(seconds: 4));
        final hash = headResult.stdout.toString().trim();
        branch = hash.isNotEmpty ? 'HEAD ($hash)' : 'HEAD';
      }

      // 2. Get status porcelain
      final statusResult = await Process.run(
        'git',
        ['status', '--porcelain=v1'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 5));

      int modified = 0;
      int staged = 0;
      int untracked = 0;

      final lines = statusResult.stdout.toString().split('\n');
      for (final line in lines) {
        if (line.length < 2) continue;
        final x = line[0];
        final y = line[1];

        if (x == '?' && y == '?') {
          untracked++;
        } else {
          if (x != ' ' && x != '?') staged++;
          if (y != ' ' && y != '?') modified++;
        }
      }

      // 3. Get ahead / behind count relative to upstream & upstream branch name
      int ahead = 0;
      int behind = 0;
      String? upstream;
      try {
        final upRes = await Process.run(
          'git',
          ['rev-parse', '--abbrev-ref', '@{upstream}'],
          workingDirectory: projectPath,
        ).timeout(const Duration(seconds: 3));
        if (upRes.exitCode == 0) {
          final u = upRes.stdout.toString().trim();
          if (u.isNotEmpty) upstream = u;
        }
      } catch (_) {}

      try {
        final syncResult = await Process.run(
          'git',
          ['rev-list', '--left-right', '--count', '@{upstream}...HEAD'],
          workingDirectory: projectPath,
        ).timeout(const Duration(seconds: 4));

        if (syncResult.exitCode == 0) {
          final parts = syncResult.stdout.toString().trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            behind = int.tryParse(parts[0]) ?? 0;
            ahead = int.tryParse(parts[1]) ?? 0;
          }
        }
      } catch (_) {
        // No upstream configured, ignore
      }

      // 4. Stash count
      bool hasStash = false;
      try {
        final stashResult = await Process.run(
          'git',
          ['stash', 'list'],
          workingDirectory: projectPath,
        ).timeout(const Duration(seconds: 4));
        hasStash = stashResult.stdout.toString().trim().isNotEmpty;
      } catch (_) {}

      // 5. Last commit details
      String? lastCommitHash;
      String? lastCommitMessage;
      DateTime? lastCommitDate;
      String? lastCommitAuthor;
      try {
        final commitResult = await Process.run(
          'git',
          ['log', '-1', '--format=%h%x00%s%x00%ct%x00%an'],
          workingDirectory: projectPath,
        ).timeout(const Duration(seconds: 4));

        if (commitResult.exitCode == 0) {
          final out = commitResult.stdout.toString().trim();
          final parts = out.split('\u0000');
          if (parts.isNotEmpty && parts[0].isNotEmpty) {
            lastCommitHash = parts[0];
          }
          if (parts.length > 1 && parts[1].isNotEmpty) {
            lastCommitMessage = parts[1];
          }
          if (parts.length > 2 && parts[2].isNotEmpty) {
            final secs = int.tryParse(parts[2]);
            if (secs != null && secs > 0) {
              lastCommitDate = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
            }
          }
          if (parts.length > 3 && parts[3].isNotEmpty) {
            lastCommitAuthor = parts[3];
          }
        }
      } catch (_) {}

      // 6. Latest tag
      String? lastTag;
      try {
        final tagResult = await Process.run(
          'git',
          ['describe', '--tags', '--abbrev=0'],
          workingDirectory: projectPath,
        ).timeout(const Duration(seconds: 3));

        if (tagResult.exitCode == 0) {
          final t = tagResult.stdout.toString().trim();
          if (t.isNotEmpty) {
            lastTag = t;
          }
        }
      } catch (_) {}

      // 7. Remote URL
      String? remoteUrl;
      try {
        final remRes = await Process.run(
          'git',
          ['remote', 'get-url', 'origin'],
          workingDirectory: projectPath,
        ).timeout(const Duration(seconds: 3));
        if (remRes.exitCode == 0) {
          final r = remRes.stdout.toString().trim();
          if (r.isNotEmpty) remoteUrl = r;
        }
      } catch (_) {}

      return GitRepoStatus(
        isGitRepo: true,
        branch: branch,
        modifiedCount: modified,
        stagedCount: staged,
        untrackedCount: untracked,
        aheadCount: ahead,
        behindCount: behind,
        hasStash: hasStash,
        lastChecked: DateTime.now(),
        lastCommitHash: lastCommitHash,
        lastCommitMessage: lastCommitMessage,
        lastCommitDate: lastCommitDate,
        lastCommitAuthor: lastCommitAuthor,
        lastTag: lastTag,
        upstream: upstream,
        remoteUrl: remoteUrl,
      );
    } catch (e, st) {
      Log.warning(_tag, 'Error checking git status for $projectPath', e, st);
      return GitRepoStatus(
        isGitRepo: false,
        lastChecked: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }

  static Future<bool> fetch(String projectPath) async {
    try {
      final res = await Process.run(
        'git',
        ['fetch'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 15));
      return res.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git fetch failed for $projectPath', e, st);
      return false;
    }
  }

  static Future<bool> pull(String projectPath) async {
    try {
      final res = await Process.run(
        'git',
        ['pull'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 20));
      return res.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git pull failed for $projectPath', e, st);
      return false;
    }
  }
}
