library ipkg;

import "dart:io";

import "package:irc/irc.dart" show Color;

import 'package:polymorphic_bot/api.dart';

String fancyPrefix(String content) => "[${Color.BLUE}${content}${Color.RESET}]";
String prefix = fancyPrefix("IPKG");

String repo = "https://raw.githubusercontent.com/PolymorphicBot/plugins/gh-pages/plugins.json";

BotConnector bot;
EventManager eventManager;

int packagesQueued = 0;

void main(List<String> args, port) {
  bot = new BotConnector(port);
  eventManager = bot.createEventManager();

  eventManager.command("ipkg", (event) {
    void reply(String content) {
      event.reply("${prefix} ${content}");
    }
    void require(String permission, void handle()) {
      bot.permission((it) => handle(), event.network, event.channel, event.user, permission);
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
      Process.run("git", ["clone", "git://github.com/PolymorphicBot/${queuedPackage}.git", "plugins/${queuedPackage}"]).then((p) {
        if (p.exitCode == 0) {
          reply("${queuedPackage} has been successfully installed!");
        } else {
          reply("${queuedPackage} failed while the Git clone occurred(error code ${p.exitCode}).");
        }
      });
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
      ProcessResult p = Process.run("rm", ["-r", "plugins/${queuedPackage}"]);
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
    void updateRepo() {
      new HttpClient().getUrl(Uri.parse(repo))
          .then((HttpClientRequest request) => request.close())
          .then((HttpClientResponse response) =>
            response.pipe(new File('plugins.json').openWrite()));
    }
    void reload() {
      bot.send("reload-plugins", {
        "network": event.network
      });
    }
    if (event.args.length == 0) {
      reply("Subcommands: install [package], upgrade [package], upgrade-all, remove [package], update-repo");
    } else if (event.args[0].toLowerCase() == "install" && event.args.length >= 2) {
      require("manage.install", () {
        String queuedPackage = event.args[1];
        reply("Queuing ${queuedPackage} to install");
        install(queuedPackage);
        reload();
      });
    } else if (event.args[0].toLowerCase() == "upgrade" && event.args.length >= 2) {
      require("manage.upgrade", () {
        String queuedPackage = event.args[1];
        reply("Queuing ${queuedPackage} to upgrade");
        upgrade(queuedPackage);
        reload();
      });
    } else if (event.args[0].toLowerCase() == "upgrade-all" && event.args.length == 1) {
      require("manage.upgrade", () {
        reply("Queuing all packages to upgrade");
        upgradeAll();
        reload();
      });
    } else if (event.args[0].toLowerCase() == "remove" && event.args.length == 2) {
      require("manage.remove", () {
        String queuedPackage = event.args[1];
        reply("Queuing ${queuedPackage} to remove");
        remove(queuedPackage);
        reload();
      });
    } else if (event.args[0].toLowerCase() == "update-repo" && event.args.length == 1) {
      require("manage.update-repo", () {
        reply("Updating repo!");
        updateRepo();
      });
    } else if (event.args[0].toLowerCase() == "queue" && event.args.length == 1) {
      require("info.queue", () {
        reply("Packages in queue: ${Color.CYAN}${packagesQueued}");
      });
    } else {}
  });
}
