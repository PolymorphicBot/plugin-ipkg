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
    void update(String queuedPackage) {
      Process.run("git", ["pull"], workingDirectory: "plugins/${queuedPackage}").then((p) {
        String stdout = p.stdout;
        if (p.exitCode == 0 && stdout.contains("Already up-to-date.")) {
          reply("Plugin already up to date!");
        } else if (p.exitCode == 0) {
          reply("Plugin updated!");
        } else {
          reply("There was a problem updating(exit code ${p.exitCode}");
        }
      });
    }
    void upgradeAll() {
      if (!checkLocalRepo()) return;
      List contents = new Directory('plugins/').listSync();
      int already = 0;
      int success = 0;
      int fail = 0;
      for (var possibleDir in contents) {
        if (possibleDir is Directory) {
          packagesQueued++;
          print("Packages in queue: ${packagesQueued}");
          Process.run("git", ["pull"], workingDirectory: possibleDir.path).then((p) {
            String stdout = p.stdout;
            print(stdout);
            if (p.exitCode == 0 && stdout.contains("Already up-to-date.")) {
              already++;
            } else if (p.exitCode == 0) {
              success++;
            } else {
              fail++;
              print("FAILURE FOR ${possibleDir.path}");
              print(stdout);
            }
            print("Package unqueued");
            packagesQueued--;
            if (packagesQueued == 0) {
              reply("${success} packages upgraded, ${already} packages already up-to-date, ${fail} packages failed upgrading.");
            }
          });
        }
      }
    }
    void remove(String queuedPackage) {
      if (!checkLocalRepo()) return;
      Process.run("rm", ["-r", queuedPackage]).then((p) {
        if (p.exitCode == 0) {
          reply("${queuedPackage} has been successfully removed!");
        } else {
          reply("${queuedPackage} failed while the remove occurred(error code ${p.exitCode}).");
        }
      });
    }
    void updateRepo() {
      new HttpClient().getUrl(Uri.parse(repo))
          .then((HttpClientRequest request) => request.close())
          .then((HttpClientResponse response) => 
              response.pipe(new File('plugins.json').openWrite()));
    }
    if (event.args.length == 0) {
      reply("Subcommands: install [package], update [package], upgrade, remove [package], update-repo");
    } else if (event.args[0].toLowerCase() == "install" && event.args.length >= 2) {
      require("manage.install", () {
        String queuedPackage = event.args[1];
        reply("Queuing ${queuedPackage} to install");
        install(queuedPackage);
      });
    } else if (event.args[0].toLowerCase() == "update" && event.args.length >= 2) {
      require("manage.update", () {
        String queuedPackage = event.args[1];
        reply("Queuing ${queuedPackage} to update");
        update(queuedPackage);
      });
    } else if (event.args[0].toLowerCase() == "upgrade" && event.args.length == 1) {
      require("manage.upgrade", () {
        reply("Queuing all packages to update");
        upgradeAll();
      });
    } else if (event.args[0].toLowerCase() == "remove" && event.args.length == 2) {
      require("manage.remove", () {
        String queuedPackage = event.args[1];
        reply("Queuing ${queuedPackage} to remove");
        remove(queuedPackage);
      });
    } else if (event.args[0].toLowerCase() == "update-repo" && event.args.length == 1) {
      require("manage.update-repo", () {
        reply("Updating repo!");
        updateRepo();
      });
    } else {}
  });
}
