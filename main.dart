library ipkg;

import "dart:convert";
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

    void info(String infoMsg) {
      event.reply("${prefix} " + Color.BLUE + infoMsg);
    }

    void error(String errorMsg) {
      event.reply("${prefix} " + Color.RED + "Error: ${errorMsg}");
    }
    
    bool checkLocalRepo() {
      return new File("plugins.json").existsSync();
    }

    bool pluginExists(String pluginName) {
      return new Directory("plugins/$pluginName").existsSync();
    }

    Future<String> getPluginJson() {
      return new File("plugins.json").readAsString();
    }

    Future<String> getPluginCloneUrl(String packageName, {bool ssh: false}) {
      return getPluginJson().then((text) {
        var json = JSON.decode(text);
        if (json[packageName] == null) {
          return null;
        }
        if (ssh) {
          return json[packageName]["git-ssh"];
        } else {
          return json[packageName]["git-https"];
        }
      });
    }
    
    void install(String queuedPackage) {
      if (!checkLocalRepo()) return;
      if (pluginExists(queuedPackage)) {
        error("Plugin '$queuedPackage' already exists");
        return;
      }
      getPluginCloneUrl(queuedPackage).then((cloneUrl) {
        if (cloneUrl == null) {
          error("Package not found");
          return;
        }
        ProcessResult p = Process.runSync("git", ["clone", cloneUrl, "plugins/${queuedPackage}"]);
        {
          if (p.exitCode == 0) {
            info("${queuedPackage} has been successfully installed!");
          } else {
            error("${queuedPackage} failed during the Git clone(error code ${p.exitCode}).");
          }
        }
      });
  }
    
    void upgrade(String queuedPackage) {
      if (!checkLocalRepo()) return;
      var p = Process.runSync("git", ["pull"], workingDirectory: "plugins/${queuedPackage}");
      {
        String stdout = p.stdout;
        if (p.exitCode == 0 && stdout.contains("Already up-to-date.")) {
          info("Plugin already up to date!");
        } else if (p.exitCode == 0) {
          info("Plugin upgraded!");
        } else {
          error("${queuedPackage} failed to be upgraded(${p.exitCode}).");
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
        info("No operations were performed on ${latest} packages.");
      } else {
        info("${success} packages were upgraded, ${fail} packages failed upgrading.");
      }
    }
    
    void remove(String queuedPackage) {
      if (!checkLocalRepo()) return;
      ProcessResult p = Process.runSync("rm", ["-r", "plugins/${queuedPackage}"]);
      {
        if (p.exitCode == 0) {
          info("${queuedPackage} was removed");
        } else {
          error("${queuedPackage} failed to be removed(${p.exitCode}).");
          print("PACKAGE FAILED");
          print("==============");
          print(queuedPackage);
          print(p.stderr);
          print("==============");
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
      info("Usage: install [package], upgrade [package], upgrade-all, remove [package], update-repo");
    } else if (event.args[0].toLowerCase() == "install" && event.args.length >= 2) {
      event.require("manage.install", () {
        String queuedPackage = event.args[1];
        info("Installing ${queuedPackage}");
        install(queuedPackage);
      });
    } else if (event.args[0].toLowerCase() == "upgrade" && event.args.length >= 2) {
      event.require("manage.upgrade", () {
        String queuedPackage = event.args[1];
        info("Upgrading ${queuedPackage}");
        upgrade(queuedPackage);
      });
    } else if (event.args[0].toLowerCase() == "upgrade-all" && event.args.length == 1) {
      event.require("manage.upgrade", () {
        info("Upgrading all packages");
        upgradeAll();
      });
    } else if (event.args[0].toLowerCase() == "remove" && event.args.length == 2) {
      event.require("manage.remove", () {
        String queuedPackage = event.args[1];
        info("Removing ${queuedPackage}");
        remove(queuedPackage);
      });
    } else if (event.args[0].toLowerCase() == "update-repo" && event.args.length == 1) {
      event.require("manage.update-repo", () {
        info("Updating repository");
        updateRepo();
      });
    } else if (event.args[0].toLowerCase() == "queue" && event.args.length == 1) {
      event.require("info.queue", () {
        info("Packages in queue: ${Color.CYAN}${packagesQueued}");
      });
    }
  });
}
