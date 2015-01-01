library ipkg;

import "dart:io";
import "package:irc/client.dart" show Color;
import 'package:polymorphic_bot/api.dart';

String fancyPrefix(String content) => "[${Color.BLUE}${content}${Color.RESET}]";
String prefix = fancyPrefix("IPKG");

String repo = "https://raw.githubusercontent.com/PolymorphicBot/plugins/gh-pages/plugins.json";

BotConnector bot;

int packagesQueued = 0;

void main(List<String> args, Plugin plugin) {
  bot = plugin.getBot();

  bot.command("ipkg", (event) {
    void reply(String content) {
      event.reply("${prefix} ${content}");
    }
    
    bool checkLocalRepo() {
      if (new File("plugins.json").existsSync()) {
        return true;
      } else {
        reply(Color.RED + "Local repo was not found.");
        return false;
      }
    }
    
    void install(String queuedPackage) {
      if (!checkLocalRepo()) return;
      ProcessResult p = Process.runSync("git", ["clone", "git://github.com/PolymorphicBot/${queuedPackage}.git", "plugins/${queuedPackage}"]);
      {
        if (p.exitCode == 0) {
          reply("${queuedPackage} has been successfully installed!");
        } else {
          reply("${queuedPackage} failed while the Git clone occurred(error code ${p.exitCode}).");
        }
      }
    }
    
    void upgrade(String queuedPackage) {
      var p = Process.runSync("git", ["pull"], workingDirectory: "plugins/${queuedPackage}");
      {
        String stdout = p.stdout;
        if (p.exitCode == 0 && stdout.contains("Already up-to-date.")) {
          reply("Plugin already up to date!");
        } else if (p.exitCode == 0) {
          reply("Plugin upgraded!");
        } else {
          reply("${queuedPackage} failed to be upgraded(${p.exitCode}).");
        }
      }
    }
    
    void upgradeAll() {
      if (!checkLocalRepo()) return;
      List contents = new Directory('plugins/').listSync();
      int latest = 0;
      int success = 0;
      int fail = 0;
      for (var possibleDir in contents) {
        if (possibleDir is Directory) {
          var p = Process.runSync("git", ["pull"], workingDirectory: possibleDir.path);
          {
            String stdout = p.stdout;
            if (p.exitCode == 0 && stdout.contains("Already up-to-date.")) {
              latest++;
            } else if (p.exitCode == 0) {
              success++;
            } else {
              fail++;
              print("PACKAGE FAILURE");
              print("===============");
              print(possibleDir.path);
              print(stdout);
              print("===============");
            }
          }
        }
      }
      if (success == 0 && fail == 0) {
        reply("No operations were performed on ${latest} packages.");
      } else {
        reply("${success} packages were upgraded, ${fail} packages failed upgrading.");
      }
    }
    
    void remove(String queuedPackage) {
      if (!checkLocalRepo()) return;
      ProcessResult p = Process.runSync("rm", ["-r", "plugins/${queuedPackage}"]);
      {
        if (p.exitCode == 0) {
          reply("${queuedPackage} was removed");
        } else {
          reply("${queuedPackage} failed to be removed(${p.exitCode}).");
          print("PACKAGE FAILED");
          print("==============");
          print(queuedPackage);
          print(p.stderr);
          print("==============");
        }
      }
    }
    
    void status(String package) {
      ProcessResult p = Process.runSync("git", ["status", "--short"], workingDirectory: "plugins/${package}");
      {
        if (p.exitCode == 0) {
          var split = p.stdout.trim().split('\n');
          split.forEach(event.replyNotice);
        } else {
          reply("Not a git repository.");
        }
      }
    }
    
    void add(String package, String files) {
      ProcessResult p = Process.runSync("git", ["add", files], workingDirectory: "plugins/${package}");
      {
        if (p.exitCode == 0) {
          reply("Success!");
        } else {
          reply("Failure.");
        }
      }
    }
    
    void commit(String package, String commitMessage) {
      ProcessResult p = Process.runSync("git", ["commit", "-m" "${commitMessage}"], workingDirectory: "plugins/${package}");
      {
        if (p.exitCode == 0) {
          reply("Commit successful(${commitMessage}).");
        } else {
          reply("Commit failed.");
          // TODO implement logging when log system is finished.
        }
      }
    }
    
    void push(String package, List<String> args) {
      var cArgs = ["push"]..addAll(args);
      ProcessResult p = Process.runSync("git", cArgs, workingDirectory: "plugins/${package}");
      {
        if (p.exitCode == 0) {
          reply("Push success.");
        } else {
          reply("Push failed.");
          reply(p.stderr);
        }
      }
    }
    
    void updateRepo() {
      new HttpClient().getUrl(Uri.parse(repo)).then((HttpClientRequest request) => request.close()).then((HttpClientResponse response) => response.pipe(new File('plugins.json').openWrite()));
    }
    
    void reload() {
      plugin.send("reload-plugins", {
        "network": event.network
      });
    }
    
    if (event.args.length == 0) {
      reply("Subcommands: install [package], upgrade [package], upgrade-all, remove [package], update-repo");
    } else if (event.args[0].toLowerCase() == "install" && event.args.length >= 2) {
      event.require("manage.install", () {
        String queuedPackage = event.args[1];
        reply("Queuing ${queuedPackage} to install");
        install(queuedPackage);
        reload();
      });
    } else if (event.args[0].toLowerCase() == "upgrade" && event.args.length >= 2) {
      event.require("manage.upgrade", () {
        String queuedPackage = event.args[1];
        reply("Queuing ${queuedPackage} to upgrade");
        upgrade(queuedPackage);
        reload();
      });
    } else if (event.args[0].toLowerCase() == "upgrade-all" && event.args.length == 1) {
      event.require("manage.upgrade", () {
        reply("Queuing all packages to upgrade");
        upgradeAll();
        reload();
      });
    } else if (event.args[0].toLowerCase() == "remove" && event.args.length == 2) {
      event.require("manage.remove", () {
        String queuedPackage = event.args[1];
        reply("Queuing ${queuedPackage} to remove");
        remove(queuedPackage);
        reload();
      });
    } else if (event.args[0].toLowerCase() == "update-repo" && event.args.length == 1) {
      event.require("manage.update-repo", () {
        reply("Updating repo!");
        updateRepo();
      });
    } else if (event.args[0].toLowerCase() == "queue" && event.args.length == 1) {
      event.require("info.queue", () {
        reply("Packages in queue: ${Color.CYAN}${packagesQueued}");
      });
    } else if (event.args[0].toLowerCase() == "add" && event.args.length >= 2) {
      event.require("dev.add", () {
        var package = event.args[1];
        var files = event.args;
        files.remove("add");
        files.remove(package);
        add(package, files.join(' '));
      });
    } else if (event.args[0].toLowerCase() == "status" && event.args.length == 2) {
      event.require("dev.status", () {
        var package = event.args[1];
        status(package);
      });
    } else if (event.args[0].toLowerCase() == "commit" && event.args.length >= 2) {
      event.require("dev.commit", () {
        var package = event.args[1];
        var commitMessageSplit = event.args;
        commitMessageSplit.remove("commit");
        commitMessageSplit.remove(package);
        commit(package, commitMessageSplit.join(' '));
      });
    } else if (event.args[0].toLowerCase() == "push" && event.args.length >= 2) {
      event.require("dev.push", () {
        var package = event.args[1];
        var args = event.args;
        args.remove("push");
        args.remove(package);
        push(package, args);
      });
    }
  });
}
