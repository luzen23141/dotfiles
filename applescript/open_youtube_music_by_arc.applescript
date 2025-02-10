#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title open_youtube_music_by_arc
# @raycast.mode silent
# @raycast.refreshTime 1h

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description open_youtube_music_by_arc

tell application "Arc"
	tell front window
			
		-- Get the properties of all tabs in space 1
		set spaceTabs to the properties of every tab
		
		repeat with i from 1 to count of spaceTabs -- Iterate with index
			set aTab to item i of spaceTabs -- Get the tab properties
			set theLocation to location of aTab

			if theLocation is "topApp" then
				set theTitle to title of aTab
				if theTitle = "YouTubeMusic" then
					-- tell tab i to select
					tell tab i to select
					exit repeat -- Stop searching after the first match.
				end if
			end if
		end repeat
	end tell

	activate
end tell
