import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:devspace/core/logging/log.dart';
import 'package:devspace/core/model/models.dart';

class GitService {
  const GitService._();

  static const String _tag = 'git';

  @visibleForTesting
  static bool disableExecutionForTesting = false;

  static Future<GitRepoStatus> checkStatus(String projectPath) async {
    if (disableExecutionForTesting) {
      return GitRepoStatus.empty();
    }
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

      // 8. Repository root
      String repoRoot = projectPath;
      try {
        final rootResult = await Process.run(
          'git',
          ['rev-parse', '--show-toplevel'],
          workingDirectory: projectPath,
        ).timeout(const Duration(seconds: 3));
        if (rootResult.exitCode == 0) {
          final r = rootResult.stdout.toString().trim();
          if (r.isNotEmpty) repoRoot = r;
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
        repoRoot: repoRoot,
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
    if (disableExecutionForTesting) return true;
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
    if (disableExecutionForTesting) return true;
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

  static Future<bool> push(String projectPath, {bool setUpstream = false}) async {
    if (disableExecutionForTesting) return true;
    try {
      final args = ['push'];
      if (setUpstream) {
        args.addAll(['-u', 'origin', 'HEAD']);
      }
      final res = await Process.run(
        'git',
        args,
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 20));
      return res.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git push failed for $projectPath', e, st);
      return false;
    }
  }

  static Future<bool> stash(String projectPath, {String? message}) async {
    if (disableExecutionForTesting) return true;
    try {
      final args = ['stash', 'push'];
      if (message != null && message.trim().isNotEmpty) {
        args.addAll(['-m', message.trim()]);
      }
      final res = await Process.run(
        'git',
        args,
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 10));
      return res.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git stash failed for $projectPath', e, st);
      return false;
    }
  }

  static Future<bool> stashPop(String projectPath) async {
    if (disableExecutionForTesting) return true;
    try {
      final res = await Process.run(
        'git',
        ['stash', 'pop'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 10));
      return res.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git stash pop failed for $projectPath', e, st);
      return false;
    }
  }

  static Future<List<String>> getBranches(String projectPath) async {
    if (disableExecutionForTesting) return const [];
    try {
      final res = await Process.run(
        'git',
        ['branch', '--list', '--no-color'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 4));
      if (res.exitCode == 0) {
        final lines = res.stdout.toString().split('\n');
        return lines
            .map((l) => l.replaceAll('*', '').trim())
            .where((l) => l.isNotEmpty && !l.startsWith('(HEAD detached'))
            .toList();
      }
    } catch (e, st) {
      Log.warning(_tag, 'Git getBranches failed for $projectPath', e, st);
    }
    return const [];
  }

  static Future<bool> checkoutBranch(String projectPath, String branch) async {
    if (disableExecutionForTesting) return true;
    try {
      final res = await Process.run(
        'git',
        ['checkout', branch],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 10));
      return res.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git checkout failed for $projectPath -> $branch', e, st);
      return false;
    }
  }

  static Future<List<GitCommitInfo>> getRecentCommits(String projectPath, {int count = 10}) async {
    if (disableExecutionForTesting) return const [];
    try {
      final res = await Process.run(
        'git',
        ['log', '-$count', '--format=%h%x00%s%x00%ct%x00%an'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 5));

      if (res.exitCode == 0) {
        final commits = <GitCommitInfo>[];
        final lines = res.stdout.toString().trim().split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          final parts = line.split('\u0000');
          if (parts.length >= 4) {
            final secs = int.tryParse(parts[2]);
            final date = secs != null && secs > 0 ? DateTime.fromMillisecondsSinceEpoch(secs * 1000) : null;
            commits.add(GitCommitInfo(
              hash: parts[0],
              message: parts[1],
              date: date,
              author: parts[3],
            ));
          }
        }
        return commits;
      }
    } catch (e, st) {
      Log.warning(_tag, 'Git getRecentCommits failed for $projectPath', e, st);
    }
    return const [];
  }

  static Future<List<GitChangedFile>> getChangedFiles(String projectPath) async {
    if (disableExecutionForTesting) return const [];
    try {
      final res = await Process.run(
        'git',
        ['status', '--porcelain=v1'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 5));

      if (res.exitCode == 0) {
        final list = <GitChangedFile>[];
        final lines = res.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.length < 3) continue;
          final x = line[0];
          final y = line[1];
          final filePath = line.substring(3).trim();

          if (x != ' ' && x != '?') {
            list.add(GitChangedFile(path: filePath, status: x, isStaged: true));
          }
          if (y != ' ') {
            list.add(GitChangedFile(path: filePath, status: y == '?' ? '?' : y, isStaged: false));
          }
        }
        return list;
      }
    } catch (e, st) {
      Log.warning(_tag, 'Git getChangedFiles failed for $projectPath', e, st);
    }
    return const [];
  }

  static Future<bool> commitAll(String projectPath, String message) async {
    if (disableExecutionForTesting) return true;
    try {
      final addRes = await Process.run(
        'git',
        ['add', '-A'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 10));
      if (addRes.exitCode != 0) return false;

      final commitRes = await Process.run(
        'git',
        ['commit', '-m', message.trim()],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 10));
      return commitRes.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git commitAll failed for $projectPath', e, st);
      return false;
    }
  }

  static Future<bool> discardAllChanges(String projectPath) async {
    if (disableExecutionForTesting) return true;
    try {
      await Process.run(
        'git',
        ['checkout', '--', '.'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 10));

      await Process.run(
        'git',
        ['clean', '-fd'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 10));
      return true;
    } catch (e, st) {
      Log.warning(_tag, 'Git discardAllChanges failed for $projectPath', e, st);
      return false;
    }
  }

  static Future<bool> createBranch(String projectPath, String branchName) async {
    if (disableExecutionForTesting) return true;
    try {
      final res = await Process.run(
        'git',
        ['checkout', '-b', branchName.trim()],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 10));
      return res.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git createBranch failed for $projectPath -> $branchName', e, st);
      return false;
    }
  }

  static Future<bool> stageFile(String projectPath, String filePath) async {
    if (disableExecutionForTesting) return true;
    try {
      final res = await Process.run(
        'git',
        ['add', '--', filePath],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 8));
      return res.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git stageFile failed for $filePath', e, st);
      return false;
    }
  }

  static Future<bool> unstageFile(String projectPath, String filePath) async {
    if (disableExecutionForTesting) return true;
    try {
      final res = await Process.run(
        'git',
        ['restore', '--staged', '--', filePath],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 8));
      return res.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git unstageFile failed for $filePath', e, st);
      return false;
    }
  }

  static Future<bool> discardFile(String projectPath, String filePath, {bool isUntracked = false}) async {
    if (disableExecutionForTesting) return true;
    try {
      if (isUntracked) {
        final res = await Process.run(
          'git',
          ['clean', '-fd', '--', filePath],
          workingDirectory: projectPath,
        ).timeout(const Duration(seconds: 8));
        return res.exitCode == 0;
      } else {
        final res = await Process.run(
          'git',
          ['checkout', 'HEAD', '--', filePath],
          workingDirectory: projectPath,
        ).timeout(const Duration(seconds: 8));
        return res.exitCode == 0;
      }
    } catch (e, st) {
      Log.warning(_tag, 'Git discardFile failed for $filePath', e, st);
      return false;
    }
  }

  static Future<String> getFileDiff(String projectPath, String filePath, {bool staged = false}) async {
    if (disableExecutionForTesting) return '';
    try {
      final args = staged
          ? ['diff', '--cached', '--', filePath]
          : ['diff', '--', filePath];
      final res = await Process.run(
        'git',
        args,
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 6));
      return res.stdout.toString();
    } catch (e, st) {
      Log.warning(_tag, 'Git getFileDiff failed for $filePath', e, st);
      return '';
    }
  }

  static Future<bool> fetchPrune(String projectPath) async {
    if (disableExecutionForTesting) return true;
    try {
      final res = await Process.run(
        'git',
        ['fetch', '--prune'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 15));
      return res.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git fetchPrune failed for $projectPath', e, st);
      return false;
    }
  }

  static Future<bool> init(String projectPath) async {
    try {
      final res = await Process.run(
        'git',
        ['init'],
        workingDirectory: projectPath,
      ).timeout(const Duration(seconds: 5));
      return res.exitCode == 0;
    } catch (e, st) {
      Log.warning(_tag, 'Git init failed for $projectPath', e, st);
      return false;
    }
  }
}
