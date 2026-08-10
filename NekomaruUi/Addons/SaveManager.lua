--[[
    NekomaruUI — SaveManager
    Simpan / load semua value element (Library.Options) ke JSON di filesystem executor.

    Pakai:
        local SaveManager = loadstring(game:HttpGet(BASE .. "Addons/SaveManager.lua"))()
        SaveManager:SetLibrary(Library)
        SaveManager:SetFolder("NekomaruHub/Universal")
        SaveManager:IgnoreThemeSettings()
        SaveManager:BuildConfigSection(Tabs.Settings)   -- bikin UI config otomatis
        SaveManager:LoadAutoloadConfig()
]]

local HttpService = game:GetService("HttpService")

local function env(n) return rawget(_G, n) or (getfenv and rawget(getfenv(), n)) end
local isfolder_f  = env("isfolder")
local makefolder_f= env("makefolder")
local isfile_f    = env("isfile")
local writefile_f = env("writefile")
local readfile_f  = env("readfile")
local delfile_f   = env("delfile")
local listfiles_f = env("listfiles")

local SaveManager = {}
SaveManager.Folder = "NekomaruUI/Configs"
SaveManager.Ignore = {}
SaveManager.Library = nil

function SaveManager:SetLibrary(lib) self.Library = lib end
function SaveManager:SetFolder(folder)
    self.Folder = folder
    self:BuildFolderTree()
end
function SaveManager:SetIgnoreIndexes(list)
    for _, k in ipairs(list or {}) do self.Ignore[k] = true end
end
function SaveManager:IgnoreThemeSettings()
    self:SetIgnoreIndexes({ "ThemeAccent", "ThemeBackground", "ThemeManager_ThemeList", "AutoloadConfig" })
end

function SaveManager:BuildFolderTree()
    if not (isfolder_f and makefolder_f) then return end
    local parts = {}
    for s in tostring(self.Folder):gmatch("[^/]+") do table.insert(parts, s) end
    local cur = ""
    for _, p in ipairs(parts) do
        cur = cur == "" and p or (cur .. "/" .. p)
        if not isfolder_f(cur) then pcall(makefolder_f, cur) end
    end
    local settings = self.Folder .. "/settings"
    if not isfolder_f(settings) then pcall(makefolder_f, settings) end
end

local function serialize(v)
    if typeof(v) == "Color3" then
        return { __type = "Color3", R = v.R, G = v.G, B = v.B }
    elseif typeof(v) == "EnumItem" then
        return { __type = "EnumItem", Value = tostring(v) }
    elseif type(v) == "table" then
        local t = { __type = "table" }
        for k, val in pairs(v) do t[tostring(k)] = val end
        return t
    end
    return v
end

local function deserialize(v)
    if type(v) == "table" and v.__type == "Color3" then
        return Color3.new(v.R, v.G, v.B)
    elseif type(v) == "table" and v.__type == "EnumItem" then
        local name = v.Value:match("Enum%.KeyCode%.(.+)")
        if name and Enum.KeyCode[name] then return Enum.KeyCode[name] end
        return nil
    elseif type(v) == "table" and v.__type == "table" then
        local t = {}
        for k, val in pairs(v) do if k ~= "__type" then t[k] = val end end
        return t
    end
    return v
end

function SaveManager:Save(name)
    if not (writefile_f and name and name ~= "") then return false, "nama config kosong" end
    self:BuildFolderTree()
    local data = { objects = {} }
    for idx, obj in pairs(self.Library.Options) do
        if not self.Ignore[idx] then
            data.objects[idx] = { type = obj.Type, value = serialize(obj.Value) }
        end
    end
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not ok then return false, "gagal encode json" end
    local okw = pcall(writefile_f, self.Folder .. "/settings/" .. name .. ".json", encoded)
    return okw, okw and "saved" or "gagal tulis file"
end

function SaveManager:Load(name)
    if not (isfile_f and readfile_f and name and name ~= "") then return false, "config invalid" end
    local path = self.Folder .. "/settings/" .. name .. ".json"
    if not isfile_f(path) then return false, "config tidak ada" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile_f(path)) end)
    if not ok then return false, "json rusak" end
    for idx, saved in pairs(data.objects or {}) do
        local obj = self.Library.Options[idx]
        if obj and obj.SetValue then
            pcall(function() obj:SetValue(deserialize(saved.value)) end)
        end
    end
    return true, "loaded"
end

function SaveManager:Delete(name)
    if not (delfile_f and name) then return false end
    local path = self.Folder .. "/settings/" .. name .. ".json"
    if isfile_f and isfile_f(path) then
        return pcall(delfile_f, path)
    end
    return false
end

function SaveManager:RefreshConfigList()
    if not listfiles_f then return {} end
    self:BuildFolderTree()
    local out = {}
    local ok, files = pcall(listfiles_f, self.Folder .. "/settings")
    if not ok then return {} end
    for _, f in ipairs(files) do
        if f:sub(-5) == ".json" then
            local n = f:match("([^/\\]+)%.json$")
            if n and n ~= "autoload" then table.insert(out, n) end
        end
    end
    table.sort(out)
    return out
end

function SaveManager:SetAutoloadConfig(name)
    if writefile_f then pcall(writefile_f, self.Folder .. "/settings/autoload.txt", name) end
end

function SaveManager:GetAutoloadConfig()
    local p = self.Folder .. "/settings/autoload.txt"
    if isfile_f and isfile_f(p) then return readfile_f(p) end
    return nil
end

function SaveManager:LoadAutoloadConfig()
    local name = self:GetAutoloadConfig()
    if name and name ~= "" then
        local ok, msg = self:Load(name)
        self.Library:Notify({ Title = "Config", Content = ok and ("Autoload: " .. name) or ("Gagal autoload: " .. tostring(msg)), Type = ok and "success" or "error" })
    end
end

--- Bikin UI config lengkap di sebuah Tab (mirip Obsidian SaveManager).
function SaveManager:BuildConfigSection(tab)
    local Library = self.Library
    local section = tab:AddSection("Configuration")
    self:BuildFolderTree()

    local nameBox = section:AddInput("SaveManager_ConfigName", { Text = "Config Name", Placeholder = "nama config" })
    local listDd  = section:AddDropdown("SaveManager_ConfigList", { Text = "Config List", Values = self:RefreshConfigList(), Placeholder = "pilih config" })
    self.Ignore["SaveManager_ConfigName"] = true
    self.Ignore["SaveManager_ConfigList"] = true

    section:AddButton({ Text = "Create Config", Variant = "accent", Callback = function()
        local ok, msg = self:Save(nameBox.Value)
        Library:Notify({ Title = "Config", Content = ok and ("Config '" .. nameBox.Value .. "' dibuat") or msg, Type = ok and "success" or "error" })
        listDd:SetValues(self:RefreshConfigList())
    end })
    section:AddButton({ Text = "Load Config", Callback = function()
        local ok, msg = self:Load(listDd.Value)
        Library:Notify({ Title = "Config", Content = ok and ("Loaded " .. tostring(listDd.Value)) or msg, Type = ok and "success" or "error" })
    end })
    section:AddButton({ Text = "Overwrite Config", Callback = function()
        local ok, msg = self:Save(listDd.Value)
        Library:Notify({ Title = "Config", Content = ok and "Config ditimpa" or msg, Type = ok and "success" or "error" })
    end })
    section:AddButton({ Text = "Delete Config", Variant = "danger", Callback = function()
        local ok = self:Delete(listDd.Value)
        Library:Notify({ Title = "Config", Content = ok and "Config dihapus" or "Gagal hapus", Type = ok and "success" or "error" })
        listDd:SetValues(self:RefreshConfigList())
    end })
    section:AddButton({ Text = "Refresh List", Callback = function()
        listDd:SetValues(self:RefreshConfigList())
        Library:Notify({ Title = "Config", Content = "List di-refresh", Type = "info" })
    end })
    section:AddButton({ Text = "Set as Autoload", Callback = function()
        if listDd.Value then
            self:SetAutoloadConfig(listDd.Value)
            Library:Notify({ Title = "Config", Content = "Autoload: " .. tostring(listDd.Value), Type = "success" })
        end
    end })

    return section
end

return SaveManager
