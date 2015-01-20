/**
	Copyright: © 2013 rejectedsoftware e.K.
	License: Subject to the terms of the GNU GPLv3 license, as written in the included LICENSE.txt file.
	Authors: Sönke Ludwig
*/
module app;

import dubregistry.dbcontroller;
import dubregistry.repositories.bitbucket;
import dubregistry.repositories.github;
import dubregistry.registry;
import dubregistry.web;
import dubregistry.api;

import std.algorithm : sort;
import std.file;
import std.path;
import userman.web;
import vibe.d;


Task s_checkTask;
DubRegistry s_registry;

void startMonitoring()
{
	void monitorNewVersions()
	{
		while(true){
			s_registry.checkForNewVersions();
			sleep(15.minutes());
		}
	}
	s_checkTask = runTask(&monitorNewVersions);
}

shared static this()
{
	setLogFile("log.txt", LogLevel.diagnostic);

	import dub.internal.utils : jsonFromFile;
	auto regsettingsjson = jsonFromFile(Path("settings.json"), true);
	auto ghuser = regsettingsjson["github-user"].opt!string;
	auto ghpassword = regsettingsjson["github-password"].opt!string;

	GithubRepository.register(ghuser, ghpassword);
	BitbucketRepository.register();

	auto router = new URLRouter;
	router.get("*", (req, res) { if (!s_checkTask.running) startMonitoring(); });

	// user management
	auto udbsettings = new UserManSettings;
	udbsettings.serviceName = "DUB - The D package registry";
	udbsettings.serviceUrl = URL("https://dub.staging.dawg.eu/");
	udbsettings.serviceEmail = "noreply@dawg.eu";
	udbsettings.databaseURL = "mongodb://127.0.0.1:27017/vpmreg_staging";
	udbsettings.requireAccountValidation = false;
	auto userdb = createUserManController(udbsettings);

	// VPM registry
	auto regsettings = new DubRegistrySettings;
	s_registry = new DubRegistry(regsettings);

	// web front end
	router.registerDubRegistryWebFrontend(s_registry, userdb);
	router.registerDubRegistryWebApi(s_registry);

	// start the web server
 	auto settings = new HTTPServerSettings;
	settings.hostName = "dub.staging.dawg.eu";
	settings.bindAddresses = ["127.0.0.1"];
	settings.port = 8005;
	settings.sessionStore = new MemorySessionStore;

	listenHTTP(settings, router);

	// poll github for new project versions
	startMonitoring();
}
