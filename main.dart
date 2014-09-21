library ipkg;

import "dart:io";

import "package:irc/irc.dart" show Color;

import 'package:polymorphic_bot/api.dart';

String fancyPrefix(String content) => "[${Color.BLUE}${content}${Color.RESET}]";
String prefix = fancyPrefix("IPKG");

BotConnector bot;
EventManager eventManager;

void main(List<String> args, port) {
  bot = new BotConnector(port);
  eventManager = bot.createEventManager();
  
  eventManager.command("ipkg", (event) {
    void reply(String content) {
      event.reply("${prefix} ${content}");
    }
    if (event.args.length == 0) {
      reply("Subcommands: install, update");
    } else if (event.args[0].toLowerCase() == "install" && event.args.length >= 2) {
      String queuedPackage = event.args[1];
      reply("Queuing ${queuedPackage} to install");
      
      Process.run("git", ["clone", "git://github.com/PolymorphicBot/${queuedPackage}.git", "plugins/${queuedPackage}"]).then((p) {
        if (p.exitCode == 0) {
          reply("${queuedPackage} has been successfully installed!");
        } else {
          reply("${queuedPackage} failed while the Git clone occurred(error code ${p.exitCode}).");
        }
      });
    } else if (event.args[0].toLowerCase() == "update" && event.args.length >= 2) {
      String queuedPackage = event.args[1];
      reply("Queuing ${queuedPackage} to update");
      
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
    } else {}
  });
}