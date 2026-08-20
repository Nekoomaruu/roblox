--[[
    AI Chatbot for Roblox — Obsidian UI
    Executor: Delta / Solara / Wave / Swift (butuh fungsi HTTP: request/http_request/syn.request)
    Library : https://github.com/deividcomsono/Obsidian

    Alur: Login (pilih provider + paste API key) -> Main Window
    Tabs  : Main | API | Prompt | Settings | UI Settings
]]

--==================================================================
-- SERVICES & EXECUTOR HTTP
--==================================================================
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local httpRequest = (syn and syn.request)
    or (http and http.request)
    or http_request
    or (fluxus and fluxus.request)
    or request

if not httpRequest then
    warn("[AI Chatbot] Executor kamu tidak mendukung HTTP request.")
end

--==================================================================
-- LOAD OBSIDIAN
--==================================================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

--==================================================================
-- CONFIG / STATE
--==================================================================
local Config = {
    Provider = "Google AI Studio",
    ApiKey = "",
    Model = "",
    MaxTokens = 512,
    Temperature = 0.7,
    SystemPrompt = "Kamu adalah asisten AI di dalam game Roblox. Jawab singkat, jelas, dan ramah.",
    StreamToChat = false,
    KeepHistory = true,
    HistoryLimit = 10,
    Timeout = 30,
}

local History = {}      -- { {role="user"/"assistant", content="..."} }
local LastReply = ""
local Busy = false

--==================================================================
-- PROVIDERS
--==================================================================
local Providers = {
    ["Google AI Studio"] = {
        KeyHint = "AIza... / AQ.Ab8... (aistudio.google.com/apikey)",
        Models = {
            "gemini-2.5-flash",
            "gemini-2.5-flash-lite",
            "gemini-2.5-pro",
        },
        Build = function(messages)
            local contents, systemText = {}, nil
            for _, m in ipairs(messages) do
                if m.role == "system" then
                    systemText = m.content
                else
                    table.insert(contents, {
                        role = (m.role == "assistant") and "model" or "user",
                        parts = { { text = m.content } },
                    })
                end
            end
            local body = {
                contents = contents,
                generationConfig = {
                    temperature = Config.Temperature,
                    maxOutputTokens = Config.MaxTokens,
                },
            }
            if systemText then
                body.systemInstruction = { parts = { { text = systemText } } }
            end
            return {
                Url = ("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent"):format(Config.Model),
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["x-goog-api-key"] = Config.ApiKey,
                },
                Body = body,
            }
        end,
        Parse = function(data)
            local c = data.candidates and data.candidates[1]
            if not c then return nil end
            local parts = c.content and c.content.parts
            if not parts then return nil end
            local out = {}
            for _, p in ipairs(parts) do
                if p.text then table.insert(out, p.text) end
            end
            return table.concat(out, "")
        end,
    },

    ["OpenRouter"] = {
        KeyHint = "sk-or-v1-... (openrouter.ai/keys)",
        Models = {
            "deepseek/deepseek-chat-v3-0324:free",
            "meta-llama/llama-3.3-70b-instruct:free",
            "google/gemini-2.0-flash-exp:free",
            "qwen/qwen-2.5-72b-instruct:free",
            "openai/gpt-4o-mini",
        },
        Build = function(messages)
            return {
                Url = "https://openrouter.ai/api/v1/chat/completions",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Authorization"] = "Bearer " .. Config.ApiKey,
                    ["HTTP-Referer"] = "https://github.com/deividcomsono/Obsidian",
                    ["X-Title"] = "Roblox AI Chatbot",
                },
                Body = {
                    model = Config.Model,
                    messages = messages,
                    temperature = Config.Temperature,
                    max_tokens = Config.MaxTokens,
                },
            }
        end,
        Parse = function(data)
            local c = data.choices and data.choices[1]
            return c and c.message and c.message.content
        end,
    },

    ["Groq"] = {
        KeyHint = "gsk_... (console.groq.com/keys)",
        Models = {
            "llama-3.3-70b-versatile",
            "llama-3.1-8b-instant",
            "openai/gpt-oss-20b",
            "openai/gpt-oss-120b",
        },
        Build = function(messages)
            return {
                Url = "https://api.groq.com/openai/v1/chat/completions",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Authorization"] = "Bearer " .. Config.ApiKey,
                },
                Body = {
                    model = Config.Model,
                    messages = messages,
                    temperature = Config.Temperature,
                    max_tokens = Config.MaxTokens,
                },
            }
        end,
        Parse = function(data)
            local c = data.choices and data.choices[1]
            return c and c.message and c.message.content
        end,
    },

    ["NVIDIA NIM"] = {
        KeyHint = "nvapi-... (build.nvidia.com)",
        Models = {
            "meta/llama-3.3-70b-instruct",
            "meta/llama-3.1-8b-instruct",
            "deepseek-ai/deepseek-r1",
            "qwen/qwen2.5-coder-32b-instruct",
        },
        Build = function(messages)
            return {
                Url = "https://integrate.api.nvidia.com/v1/chat/completions",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Authorization"] = "Bearer " .. Config.ApiKey,
                },
                Body = {
                    model = Config.Model,
                    messages = messages,
                    temperature = Config.Temperature,
                    max_tokens = Config.MaxTokens,
                },
            }
        end,
        Parse = function(data)
            local c = data.choices and data.choices[1]
            return c and c.message and c.message.content
        end,
    },
}

local ProviderNames = { "Google AI Studio", "OpenRouter", "Groq", "NVIDIA NIM" }

local function ModelsOf(provider)
    return Providers[provider] and Providers[provider].Models or {}
end

--==================================================================
-- CORE: SEND MESSAGE
--==================================================================
local function BuildMessages(userText)
    local messages = {}
    if Config.SystemPrompt ~= "" then
        table.insert(messages, { role = "system", content = Config.SystemPrompt })
    end
    if Config.KeepHistory then
        local start = math.max(1, #History - Config.HistoryLimit * 2 + 1)
        for i = start, #History do
            table.insert(messages, History[i])
        end
    end
    table.insert(messages, { role = "user", content = userText })
    return messages
end

local function AskAI(userText)
    local provider = Providers[Config.Provider]
    if not provider then return nil, "Provider tidak valid." end
    if Config.ApiKey == "" then return nil, "API key masih kosong." end
    if Config.Model == "" then return nil, "Model belum dipilih." end
    if not httpRequest then return nil, "Executor tidak mendukung HTTP request." end

    local req = provider.Build(BuildMessages(userText))

    local requestOptions = {
        Url = req.Url,
        Method = "POST",
        Headers = req.Headers,
        Body = HttpService:JSONEncode(req.Body),
    }

    -- Nama opsi timeout berbeda-beda antar executor; Delta mengabaikannya
    -- bila tidak didukung, jadi request tetap dapat berjalan.
    requestOptions.Timeout = Config.Timeout

    local ok, res = pcall(httpRequest, requestOptions)

    if not ok then return nil, "Request gagal: " .. tostring(res) end
    if not res then return nil, "Tidak ada respons dari server." end

    -- Executor tidak seragam: ada yang memakai Body/StatusCode, ada body/Status.
    local responseBody = res.Body or res.body
    local statusCode = res.StatusCode or res.Status or res.status_code or 0
    if not responseBody or responseBody == "" then
        return nil, "Respons kosong dari server (status " .. tostring(statusCode) .. ")."
    end

    local decoded
    local okDecode, err = pcall(function()
        decoded = HttpService:JSONDecode(responseBody)
    end)
    if not okDecode then return nil, "Respons bukan JSON: " .. tostring(err) end

    if decoded.error then
        local msg = type(decoded.error) == "table" and (decoded.error.message or decoded.error.code) or decoded.error
        return nil, "API error: " .. tostring(msg)
    end

    local text = provider.Parse(decoded)
    if not text or text == "" then
        return nil, "Balasan kosong (status " .. tostring(statusCode) .. ")"
    end

    return text
end

--==================================================================
-- LOGIN WINDOW
--==================================================================
local LoginWindow = Library:CreateWindow({
    Title = "AI Chatbot — Login",
    Footer = "Obsidian UI • v1.0",
    Icon = "key-round",
    NotifySide = "Right",
    ShowCustomCursor = true,
    Size = UDim2.fromOffset(480, 360),
    Center = true,
    AutoShow = true,
})

local LoginTab = LoginWindow:AddTab("Login", "log-in")
local LoginBox = LoginTab:AddLeftGroupbox("Autentikasi", "shield-check")

LoginBox:AddLabel("Pilih provider, lalu tempel API key kamu.", true)

LoginBox:AddDropdown("LoginProvider", {
    Values = ProviderNames,
    Default = 1,
    Multi = false,
    Text = "Provider",
    Tooltip = "Sumber model AI yang mau dipakai",
    Callback = function(value)
        Config.Provider = value
        Library:Notify(("Hint key: %s"):format(Providers[value].KeyHint), 5)
    end,
})

LoginBox:AddInput("LoginKey", {
    Default = "",
    Numeric = false,
    Finished = false,
    ClearTextOnFocus = false,
    Text = "API Key",
    Tooltip = "Contoh Google AI Studio: AQ.Ab8RN6I... / AIzaSy...",
    Placeholder = "Tempel API key di sini",
    Callback = function(value)
        Config.ApiKey = value
    end,
})

LoginBox:AddToggle("SaveKey", {
    Text = "Ingat API key di config",
    Default = false,
    Tooltip = "Simpan key ke file config lokal executor",
})

local MainWindowBuilt = false
local BuildMainWindow -- forward declaration

LoginBox:AddButton({
    Text = "Login / Connect",
    Func = function()
        if Busy then return Library:Notify("Koneksi sedang dites...", 3) end
        if Config.ApiKey:gsub("%s", "") == "" then
            return Library:Notify("API key tidak boleh kosong!", 4)
        end
        Config.ApiKey = Config.ApiKey:gsub("^%s+", ""):gsub("%s+$", "")
        Config.Model = ModelsOf(Config.Provider)[1] or ""

        Busy = true
        Library:Notify(("Mengetes %s (%s)..."):format(Config.Provider, Config.Model), 4)
        task.spawn(function()
            local reply, err = AskAI("Balas hanya dengan kata: OK")
            Busy = false
            if not reply then
                return Library:Notify("Login gagal: " .. tostring(err), 8)
            end
            if MainWindowBuilt then return end

            MainWindowBuilt = true
            Library:Notify(("Terhubung ke %s (%s)"):format(Config.Provider, Config.Model), 4)

            -- Obsidian versi terbaru tidak punya Window:Dialog(). Jangan Unload
            -- library sebelum membuat menu utama karena Unload memutus semua event.
            LoginWindow:Toggle(false)
            task.wait(0.25)
            BuildMainWindow()
        end)
    end,
    DoubleClick = false,
})

LoginBox:AddButton({
    Text = "Test Koneksi",
    Func = function()
        Config.Model = ModelsOf(Config.Provider)[1] or ""
        Library:Notify("Mengetes API key...", 3)
        task.spawn(function()
            local reply, err = AskAI("ping")
            if reply then
                Library:Notify("API key valid ✔", 4)
            else
                Library:Notify("Gagal: " .. tostring(err), 6)
            end
        end)
    end,
})

--==================================================================
-- MAIN WINDOW
--==================================================================
function BuildMainWindow()
    local Window = Library:CreateWindow({
        Title = "AI Chatbot",
        Footer = ("%s • %s"):format(LocalPlayer.Name, Config.Provider),
        Icon = "bot",
        NotifySide = "Right",
        ShowCustomCursor = true,
        TabWidth = 150,
        Size = UDim2.fromOffset(720, 520),
        Center = true,
        AutoShow = true,
    })

    local Tabs = {
        Main = Window:AddTab("Main", "message-circle"),
        API = Window:AddTab("API", "key-round"),
        Prompt = Window:AddTab("Prompt", "file-text"),
        Settings = Window:AddTab("Settings", "settings"),
        UI = Window:AddTab("UI Settings", "sliders-horizontal"),
    }

    ----------------------------------------------------------------
    -- MAIN TAB
    ----------------------------------------------------------------
    local ChatBox = Tabs.Main:AddLeftGroupbox("Chatbot", "message-square")
    local OutBox = Tabs.Main:AddRightGroupbox("Jawaban AI", "sparkles")

    local StatusLabel = ChatBox:AddLabel("Status: idle")
    local ReplyLabel = OutBox:AddLabel("Belum ada jawaban.", true)

    local CurrentInput = ""

    ChatBox:AddInput("ChatInput", {
        Default = "",
        Finished = false,
        Text = "Pesan kamu",
        Placeholder = "Tulis pertanyaan...",
        Callback = function(v) CurrentInput = v end,
    })

    ChatBox:AddDropdown("ModelSelect", {
        Values = ModelsOf(Config.Provider),
        Default = 1,
        Text = "Select Model",
        Tooltip = "Model AI yang dipakai untuk menjawab",
        Callback = function(v) Config.Model = v end,
    })

    ChatBox:AddSlider("MaxTokens", {
        Text = "Panjang output (tokens)",
        Default = Config.MaxTokens,
        Min = 64,
        Max = 4096,
        Rounding = 0,
        Compact = false,
        Callback = function(v) Config.MaxTokens = v end,
    })

    ChatBox:AddSlider("Temperature", {
        Text = "Kreativitas (temperature)",
        Default = Config.Temperature,
        Min = 0,
        Max = 2,
        Rounding = 2,
        Callback = function(v) Config.Temperature = v end,
    })

    local function Send()
        if Busy then return Library:Notify("Masih memproses...", 3) end
        local text = (CurrentInput or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then return Library:Notify("Pesan kosong.", 3) end

        Busy = true
        StatusLabel:SetText("Status: mengirim...")
        ReplyLabel:SetText("Berpikir...")

        task.spawn(function()
            local reply, err = AskAI(text)
            Busy = false
            if reply then
                LastReply = reply
                table.insert(History, { role = "user", content = text })
                table.insert(History, { role = "assistant", content = reply })
                ReplyLabel:SetText(reply)
                StatusLabel:SetText("Status: selesai")
                if Config.StreamToChat then
                    local chunk = reply:sub(1, 190)
                    pcall(function()
                        game:GetService("ReplicatedStorage")
                            :WaitForChild("DefaultChatSystemChatEvents")
                            :WaitForChild("SayMessageRequest")
                            :FireServer(chunk, "All")
                    end)
                end
            else
                ReplyLabel:SetText("Error: " .. tostring(err))
                StatusLabel:SetText("Status: error")
                Library:Notify(tostring(err), 6)
            end
        end)
    end

    ChatBox:AddButton({ Text = "Kirim", Func = Send })
        :AddButton({ Text = "Clear History", Func = function()
            History = {}
            Library:Notify("Riwayat chat dibersihkan.", 3)
        end })

    OutBox:AddButton({
        Text = "Copy jawaban",
        Func = function()
            local clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
            if clip and LastReply ~= "" then
                clip(LastReply)
                Library:Notify("Jawaban disalin ke clipboard.", 3)
            else
                Library:Notify("Clipboard tidak tersedia / jawaban kosong.", 4)
            end
        end,
    })

    OutBox:AddToggle("StreamToChat", {
        Text = "Kirim jawaban ke chat game",
        Default = Config.StreamToChat,
        Tooltip = "Hati-hati: bisa kena moderasi/kick",
        Callback = function(v) Config.StreamToChat = v end,
    })

    ----------------------------------------------------------------
    -- API TAB
    ----------------------------------------------------------------
    local ApiBox = Tabs.API:AddLeftGroupbox("Provider & Key", "key-round")
    local ApiInfo = Tabs.API:AddRightGroupbox("Info", "info")

    local KeyHintLabel = ApiInfo:AddLabel("Hint: " .. Providers[Config.Provider].KeyHint, true)
    ApiInfo:AddLabel("Key hanya dipakai lokal untuk request ke provider.", true)
    ApiInfo:AddDivider()
    local UsageLabel = ApiInfo:AddLabel("Pesan tersimpan: 0", true)

    ApiBox:AddDropdown("ApiProvider", {
        Values = ProviderNames,
        Default = table.find(ProviderNames, Config.Provider) or 1,
        Text = "Ganti Provider",
        Callback = function(v)
            Config.Provider = v
            Config.Model = ModelsOf(v)[1] or ""
            KeyHintLabel:SetText("Hint: " .. Providers[v].KeyHint)
            Options.ModelSelect:SetValues(ModelsOf(v))
            Options.ModelSelect:SetValue(Config.Model)
            Library:Notify("Provider diganti ke " .. v, 4)
        end,
    })

    ApiBox:AddInput("ApiKeyInput", {
        Default = Config.ApiKey,
        Text = "API Key",
        Placeholder = "Tempel API key baru",
        Callback = function(v) Config.ApiKey = v end,
    })

    ApiBox:AddInput("CustomModel", {
        Default = "",
        Text = "Custom model (opsional)",
        Placeholder = "contoh: gemini-2.5-flash",
        Finished = true,
        Callback = function(v)
            if v ~= "" then
                Config.Model = v
                Library:Notify("Model custom: " .. v, 4)
            end
        end,
    })

    ApiBox:AddSlider("Timeout", {
        Text = "Timeout (detik)",
        Default = Config.Timeout,
        Min = 5,
        Max = 120,
        Rounding = 0,
        Callback = function(v) Config.Timeout = v end,
    })

    ApiBox:AddButton({
        Text = "Test API Key",
        Func = function()
            Library:Notify("Mengetes...", 3)
            task.spawn(function()
                local reply, err = AskAI("ping")
                Library:Notify(reply and "API key valid ✔" or ("Gagal: " .. tostring(err)), 5)
            end)
        end,
    }):AddButton({
        Text = "Hapus API Key",
        Func = function()
            Config.ApiKey = ""
            Options.ApiKeyInput:SetValue("")
            Library:Notify("API key dihapus.", 3)
        end,
    })

    task.spawn(function()
        while Library and not Library.Unloaded do
            UsageLabel:SetText(("Pesan tersimpan: %d"):format(#History))
            task.wait(2)
        end
    end)

    ----------------------------------------------------------------
    -- PROMPT TAB
    ----------------------------------------------------------------
    local PromptBox = Tabs.Prompt:AddLeftGroupbox("System Prompt", "file-text")
    local PresetBox = Tabs.Prompt:AddRightGroupbox("Preset", "layers")

    PromptBox:AddInput("SystemPrompt", {
        Default = Config.SystemPrompt,
        Text = "Instruksi AI",
        Placeholder = "Kepribadian / aturan jawaban",
        Finished = true,
        Callback = function(v) Config.SystemPrompt = v end,
    })

    PromptBox:AddToggle("KeepHistory", {
        Text = "Ingat percakapan",
        Default = Config.KeepHistory,
        Callback = function(v) Config.KeepHistory = v end,
    })

    PromptBox:AddSlider("HistoryLimit", {
        Text = "Jumlah pesan diingat",
        Default = Config.HistoryLimit,
        Min = 1,
        Max = 30,
        Rounding = 0,
        Callback = function(v) Config.HistoryLimit = v end,
    })

    local Presets = {
        ["Asisten Game"] = "Kamu asisten AI di dalam game Roblox. Jawab singkat dan ramah.",
        ["Translator"] = "Terjemahkan pesan user ke Bahasa Indonesia dan Inggris. Tanpa penjelasan.",
        ["Coder Lua"] = "Kamu ahli Roblox Luau. Balas dengan kode yang rapi dan penjelasan singkat.",
        ["Roleplay NPC"] = "Kamu NPC pedagang di dunia fantasi. Selalu in-character.",
    }
    local PresetNames = {}
    for k in pairs(Presets) do table.insert(PresetNames, k) end
    table.sort(PresetNames)

    PresetBox:AddDropdown("PresetSelect", {
        Values = PresetNames,
        Default = 1,
        Text = "Pilih preset",
        Callback = function(v)
            Config.SystemPrompt = Presets[v]
            Options.SystemPrompt:SetValue(Presets[v])
        end,
    })

    ----------------------------------------------------------------
    -- SETTINGS TAB
    ----------------------------------------------------------------
    local SetBox = Tabs.Settings:AddLeftGroupbox("Umum", "settings")

    SetBox:AddLabel("Keybind menu"):AddKeyPicker("MenuKeybind", {
        Default = "RightShift",
        NoUI = true,
        Text = "Buka/tutup menu",
        Callback = function() end,
    })

    SetBox:AddButton({
        Text = "Unload Script",
        Func = function() Library:Unload() end,
        DoubleClick = true,
    })

    Library.ToggleKeybind = Options.MenuKeybind

    ----------------------------------------------------------------
    -- UI SETTINGS / SAVE MANAGER
    ----------------------------------------------------------------
    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind", "ApiKeyInput", "LoginKey" })
    ThemeManager:SetFolder("AIChatbot")
    SaveManager:SetFolder("AIChatbot/configs")
    SaveManager:BuildConfigSection(Tabs.UI)
    ThemeManager:ApplyToTab(Tabs.UI)

    Library:OnUnload(function()
        Library.Unloaded = true
    end)
end

Library:Notify("Silakan login dulu: pilih provider + API key.", 6)
