#!/usr/bin/osascript
-- Copyright 2015 Google Inc. All Rights Reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http:--www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.


-- Activates all Steam keys' bundle from an opened web page into Steam.
-- Intended to use for Humble Bundle automation.

-- Required to run from the command line:
tell application "System Events"
	set steam_application to application "/Applications/Steam.app"

	repeat
		-- Load page from browser
		set user_browser to my GetUserBrowser()
		set page_contents to my GetPageContents(user_browser)

		-- Search for the Steam Keys in the page content
		set steam_keys to {}
		repeat with possible_key in paragraphs of page_contents
			-- Check if it is a Key
			if (possible_key's length) is greater than 9 and (possible_key's length) is less than 32 then
				set only_right_characters to true
				set contains_letter to false
				repeat with key_char in the characters of possible_key
					considering case
						if key_char is not in the characters of "ABCDEFGHIJKLMNOPQRSTUVWXYZ-0123456789_" then
							set only_right_characters to false
						end if
						if key_char is in the characters of "ABCDEFGHIJKLMNOPQRSTUVWXYZ" then
							set contains_letter to true
						end if
					end considering
				end repeat
				if only_right_characters and contains_letter then
					copy possible_key as string to the end of steam_keys
				end if
			end if
		end repeat

		-- Making sure keys are loaded
		if steam_keys's length is 0 then
			display dialog "This application will read Steam keys from a web page and will activate them one by one.

Looks like we can not find any Steam keys in your " & user_browser & ".
Please, make sure correct site's page is loaded and keys are visible." with title "Loading Steam keys" buttons {"Cancel", "Yes, now I can see my Steam keys in " & user_browser} default button 2
		else
			exit repeat
		end if
	end repeat

	-- Starting Steam and asking user for confirmation
	activate steam_application
	set AppleScript's text item delimiters to "
"
	display dialog ("Ready to activate next Steam keys:
" & steam_keys as string) & "

After activation process is started it's recommended to not to touch you Mac until its is finished." with title "Loading Steam keys" buttons {"Cancel", "I promise to not to touch my Mac"}
	activate steam_application
	set successes to 0
	-- provides some guaranties against data races
	repeat while successes is less than 5
		-- waiting for Steam app to load
		tell process "Steam"
			if (count of windows) is 0 then
				-- Steam is loaded, no windows open
				set successes to successes + 1
			end if
			if (count of (windows whose name is not "Steam")) is not 0 then
				set successes to successes + 1
			end if
			-- Special case for Steam window, waiting for a big one
			set found to false
			repeat with current_window in (windows whose name is "Steam")
				-- some weird hack to get around AppleScript's type system
				copy (current_window's size) to s
				if s's first item is greater than 600 and s's second item is greater than 400 then
					set successes to successes + 1
				end if
			end repeat
		end tell
		my SmallDelay()
	end repeat

	set failed_steam_keys to {}

	-- Entering all the keys gathered
	repeat with steam_key in steam_keys
		tell process "Steam"
			-- Close all opened windows
			my SmallDelay()
			repeat
				set window_menu_size to count of menu items of menus of menu bar item "Window" of menu bars
				click menu item "Close" of menus of menu bar item "Window" of menu bars
				delay 1
				if window_menu_size is equal to (count of menu items of menus of menu bar item "Window" of menu bars) then
					-- closing until everythin is closed
					exit repeat
				end if
			end repeat
			-- Click "Activate" in menu
			click menu item "Activate a Product on Steam..." of menus of menu bar item "Games" of menu bars
			-- Go to product code activation page
			my BigDelay()
			keystroke return
			my BigDelay()
			keystroke return
			-- Copy & Pasting Key
			set the clipboard to steam_key
			repeat 3 times
				my SmallDelay()
				keystroke tab
			end repeat
			my SmallDelay()
			key down command
			my SmallDelay()
			keystroke "v"
			my SmallDelay()
			key up command
			my SmallDelay()
			-- OK'ing all requests until window is closed
			set successes to 0
			-- provides some guaranties against data races
			repeat while successes is less than 3
				if (count of (windows whose name contains "Error" and name starts with "Steam")) is not 0 then
					set result to display dialog "Hmm... there is some kind of problem during activation of this key:
" & steam_key & "

Anyway, I'll continue by myself after 5 seconds.
Please wait..." with title "Loading Steam keys" buttons {"Cancel"} cancel button 1 giving up after 5
					copy steam_key as string to the end of failed_steam_keys
					tell steam_application to activate
					keystroke return
				end if
				if (count of (windows whose name is "Product Activation" or name starts with "Install")) is not 0 then
					set successes to 0
					keystroke return
				else
					set successes to successes + 1
				end if
				my SmallDelay()
			end repeat
		end tell
	end repeat
	if failed_steam_keys's length is not 0 then
		set AppleScript's text item delimiters to "
"
		display dialog ("These keys were not activated for some reason:
" & failed_steam_keys as string) & "

But usually that's expected as you can not install Windows games on a Mac." with title "Loading Steam keys" buttons {"Great!"} default button 1
	else
		display dialog "It looks to me that your keys are imported, but it's always a good idea to double-check." with title "Loading Steam keys" buttons {"Great!"}
	end if
end tell

on BigDelay()
	delay 2
end BigDelay

on SmallDelay()
	delay 0.5
end SmallDelay

on GetUserBrowser()
	tell application "SystemUIServer"
		set available_browsers to {"Safari", "Google Chrome"}
		set default_browser to (name of my GetDefaultBrowser())

		if my ApplicationIsRunning(default_browser) and available_browsers contains default_browser then
			return default_browser
		else
			set running_browsers to {}
			repeat with browser in available_browsers
				if my ApplicationIsRunning(browser) then
					set running_browsers to running_browsers & browser
				end if
			end repeat

			set num_running to count of running_browsers
			if num_running is equal to 0 then
				-- This is bad, defaulting to catch-all case
			else if num_running is equal to 1 then
				return item 1 of running_browsers
			else
				return button returned of (display dialog "Which browser do you want to use?" buttons ({"Cancel"} & running_browsers) default button 2)
			end if
		end if
	end tell
	return "Safari or Chrome"
end GetUserBrowser

on GetPageContents(user_browser)
	if user_browser is equal to "Safari" then
		tell application user_browser to set page_contents to the text of document 1
	else if user_browser is equal to "Google Chrome" then
		tell application "Google Chrome" to tell active tab of window 1
			set page_contents to execute javascript "document.body.innerText"
		end tell
	else
		-- We always retutn string
		return ""
	end if
	return page_contents
end GetPageContents

-- From: http://vgable.com/blog/2009/04/24/how-to-check-if-an-application-is-running-with-applescript/
on ApplicationIsRunning(appName)
	tell application "System Events" to set appNameIsRunning to exists (processes where name is appName)
	return appNameIsRunning
end ApplicationIsRunning

-- From: https://github.com/porada/toggle-default-browser/blob/master/toggle.applescript
on GetDefaultBrowser()
	try
		return (application id GetDefaultBrowserBundleIndentifier() as application)
	on error
		-- Use Safari as the fallback browser
		-- if `GetDefaultBrowserBundleIndentifier` doesn't find anything
		return application "Safari"
	end try
end GetDefaultBrowser

on GetDefaultBrowserBundleIndentifier()
	-- Use `PlistBuddy` to parse the LaunchServices.plist:
	-- extract `LSHandlerRoleAll` from a dict that contains `LSHandlerURLScheme = http`
	do shell script "/usr/libexec/PlistBuddy -c 'Print :LSHandlers' " & (POSIX path of (path to preferences) as Unicode text) & "com.apple.LaunchServices.plist | " & "grep 'LSHandlerURLScheme = http$' -C 2 | grep 'LSHandlerRoleAll = ' | cut -d '=' -f 2 | tr -d ' '"
end GetDefaultBrowserBundleIndentifier
