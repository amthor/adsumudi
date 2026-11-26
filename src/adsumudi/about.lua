-- about.lua
-- Metainformation about the program.

--- URL encoded as a fully-qualified (`full`) and human-readable (`display`) string.
--- @class url
--- @field full    string fully-qualified URL
--- @field display string human-readable abbreviation

--- Program metadata package.
--- @class about
--- @field name        string program name
--- @field version     string program version
--- @field description string short program description
--- @field developer   string developer name
--- @field urlproject  url    repository URL
--- @field urlweb      url    web app URL
--- @field pdfsubject  string "subject" meta of generated sheet
--- @field pdfauthor   string "author" meta of a generated sheet
--- @field pdfcreator  string "creator" meta of a generated sheet
--- @field usageterms  string usage terms of a generated sheet

--- Program name.
--- @type string
local NAME = "Adsumudi"

--- Program version.
--  Adsumudi uses SemVer: major revisions (first digit) are only such that break
--  the public interface.
--- @type string
local VERSION = "1.1.0"

--- Program description.
--- @type string
local DESCRIPTION = "Adsumudi Rechenblattgenerator"

--- Human program developer.
--- @type string
local DEVELOPER = "Peter Amthor"

--- GitHub project URL.
--- @type url
local URLPROJECT = { full = "https://github.com/amthor/adsumudi/", display = "github.com/amthor/adsumudi" }

--- Web app URL.
--- @type url
local URLWEB = { full = "https://amthor.github.io/adsumudi/", display = "amthor.github.io/adsumudi" }

--- Hint at this program for sheet creation.
--- @type string
local CREATEDBY = "Erstellt mit Adsumudi " .. VERSION .. " (" .. URLPROJECT.full .. ")"

--- Sheet usage terms and conditions.
--- @type string
local USAGETERMS = "Dieses Blatt ist gemeinfrei (CC0 1.0) und darf ohne Einschränkung verwendet werden."

--- Full metadata.
--- @type about
local M = {
	name = NAME,
	version = VERSION,
	description = DESCRIPTION,
	developer = DEVELOPER,
	urlproject = URLPROJECT,
	urlweb = URLWEB,
	pdfsubject = CREATEDBY .. ". " .. USAGETERMS,
	pdfauthor = DESCRIPTION, -- reusing the short description,
	pdfcreator = DESCRIPTION, -- reusing the short description
	usageterms = USAGETERMS,
}
return M
