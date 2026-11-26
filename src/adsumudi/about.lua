-- about.lua
-- Metainformation about the program.

--- URL encoded as a fully-qualified (`full`) and human-readable (`display`) string.
--- @class url
--- @field full    string fully-qualified URL
--- @field display string human-readable abbreviation

--- Program metadata package.
--- @class about
--- @field name        string full program name
--- @field version     string program version
--- @field description string short description
--- @field author      string human name
--- @field createdby   string declaration of source
--- @field urlproject  url    repository URL
--- @field urlweb      url    web app URL
--- @field terms       string usage terms and conditions

--- Full program name.
--- @type string
local NAME = "Adsumudi Rechenblattgenerator"

--- Program version.
--  Adsumudi uses SemVer: major revisions (first digit) are only such that break
--  the public interface.
--- @type string
local VERSION = "1.1.0"

--- Program author.
--- @type string
local AUTHOR = "Peter Amthor"

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
local TERMS = "Dieses Blatt ist gemeinfrei (CC0 1.0) und darf ohne Einschränkung verwendet werden."

--- Full metadata.
--- @type about
local M = {
    name = NAME,
    version = VERSION,
    description = CREATEDBY .. ". \n" .. TERMS,
    author = AUTHOR,
    createdby = CREATEDBY,
    urlproject = URLPROJECT,
    urlweb = URLWEB,
    terms = TERMS,
}
return M
