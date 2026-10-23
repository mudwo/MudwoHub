--[[
	MudwoHub UI -- neobrutalist, preto e branco.
	borda grossa, sombra chapada (sem blur), zero gradiente, zero canto arredondado.

	drop-in pro MudwoHub.lua: loadstring -> API:CreateWindow{...}

	Window :CreateWindow{ Title, SubTitle, ToggleKey, Theme, Accent, AutoSave }
	Window :Notify{ Title, Content, Duration, Kind }
	Window :AddTab{ Title, Icon }
	Window :AddProfileManager(tab, { Section })
	Window :SetConfig(tbl, save) / :GetActiveProfile() / :SetAccent(Color3) / :Destroy()
	Window.Options[key] -> { Set(v, silent), Get(), Value }

	Tab :AddSection(title) / :AddParagraph{...} / :AddToggle(key,{...}) / :AddSlider(key,{...})
	    :AddDropdown(key,{...}) / :AddButton{...} / :AddColorPicker(key,{...}) / :AddKeybind(key,{...})
	    :AddLabel{...}
]]

local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local INK = Color3.fromRGB(0, 0, 0)
local PAPER = Color3.fromRGB(255, 255, 255)
local PAPER2 = Color3.fromRGB(228, 228, 228)
local MUTED = Color3.fromRGB(105, 105, 105)

local FONT = Enum.Font.Code
local SH = 6
local TWEEN = TweenInfo.new(0.08, Enum.EasingStyle.Linear)

local API = {}
local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab

-- ===== helpers ========================================================

local function new(class, props, parent)
	local o = Instance.new(class)

	for k, v in pairs(props or {}) do
		o[k] = v
	end

	if parent then
		o.Parent = parent
	end

	return o
end

local function border(o, thickness)
	new("UIStroke", {
		Color = INK,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	}, o)
end

local function solid(parent, x, y, w, h, z)
	return new("Frame", {
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Position = UDim2.new(x.Scale, x.Offset, y.Scale, y.Offset),
		Size = UDim2.new(w.Scale, w.Offset, h.Scale, h.Offset),
		ZIndex = z
	}, parent)
end

local function shadow(parent, pos, size, px, z)
	return new("Frame", {
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Position = UDim2.new(pos.X.Scale, pos.X.Offset + px, pos.Y.Scale, pos.Y.Offset + px),
		Size = size,
		ZIndex = z or 102
	}, parent)
end

local function text(parent, props)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or INK
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left

	return new("TextLabel", props, parent)
end

local function gray(c)
	if typeof(c) ~= "Color3" then
		return INK
	end

	local l = math.floor((c.R * 0.299 + c.G * 0.587 + c.B * 0.114) * 255 + 0.5)

	return Color3.fromRGB(l, l, l)
end

local function readable(bg)
	if bg.R * 0.299 + bg.G * 0.587 + bg.B * 0.114 > 0.55 then
		return INK
	end

	return PAPER
end

-- accent claro vira preto no "ligado": branco em cima de branco nao le
local function fillOf(c)
	if c.R * 0.299 + c.G * 0.587 + c.B * 0.114 > 0.8 then
		return INK
	end

	return c
end

local function wrapSet(el, fn)
	-- o hub chama el.Set(valor, silent) sem dois-pontos; aceita os dois jeitos
	return function(a, b)
		if a == el then
			return fn(b)
		end

		return fn(a, b)
	end
end

local function round(x)
	return math.floor(x + 0.5)
end

-- container de uma linha: e ele que o UIListLayout posiciona, sombras ficam dentro
local function slot(parent, height, order, auto)
	local s = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -6, 0, height),
		LayoutOrder = order,
		ZIndex = 103
	}, parent)

	if auto then
		s.AutomaticSize = Enum.AutomaticSize.Y
	end

	return s
end

-- ===== notificacao ====================================================

local function makeNotify(win, cfg)
	local wrap = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 400
	}, win.NotifyHolder)

	local box = new("Frame", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -SH, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 401
	}, wrap)

	border(box, 3)

	local nsh = new("Frame", {
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Position = UDim2.new(0, SH, 0, SH),
		Size = UDim2.new(1, -SH, 0, 0),
		ZIndex = 400
	}, wrap)

	box:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		nsh.Size = UDim2.new(1, -SH, 0, box.AbsoluteSize.Y)
	end)

	new("Frame", {
		BackgroundColor3 = (cfg.Kind == "error" and INK or cfg.Kind == "warning" and MUTED or PAPER),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 10, 1, 0),
		ZIndex = 402
	}, box)

	local pad = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 10),
		Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 402
	}, box)

	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder
	}, pad)

	new("UIPadding", {
		PaddingBottom = UDim.new(0, 10)
	}, pad)

	text(pad, {
		Text = string.upper(tostring(cfg.Title or "hub")),
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		ZIndex = 403
	})

	text(pad, {
		Text = string.upper(tostring(cfg.Kind or "info")),
		TextSize = 9,
		TextColor3 = MUTED,
		Size = UDim2.new(1, 0, 0, 12),
		LayoutOrder = 2,
		ZIndex = 403
	})

	text(pad, {
		Text = tostring(cfg.Content or ""),
		TextSize = 12,
		TextColor3 = Color3.fromRGB(35, 35, 35),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		ZIndex = 403
	})

	task.delay(cfg.Duration or 5, function()
		if not box.Parent then
			return
		end

		TweenService:Create(box, TWEEN, {BackgroundTransparency = 1}):Play()

		for _, d in ipairs(box:GetDescendants()) do
			pcall(function()
				d.BackgroundTransparency = 1
				d.TextTransparency = 1
			end)
		end

		task.wait(0.12)
		wrap:Destroy()
	end)

	return box
end

-- ===== janela =========================================================

function API.CreateWindow(self, cfg)
	cfg = cfg or {}

	local win = setmetatable({}, Window)
	win.Options = {}
	win.Accent = gray(cfg.Accent or INK)
	win.AutoSave = cfg.AutoSave or "mudwoui"
	win.Profile = "Padrao"
	win.Profiles = { "Padrao" }
	win.Conns = {}
	win.Painters = {}
	win.Destroyed = false

	local parent = game:GetService("CoreGui")

	pcall(function()
		if type(gethui) == "function" then
			parent = gethui()
		end
	end)

	local gui = new("ScreenGui", {
		Name = "MudwoHubUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 999999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	}, parent)

	pcall(function()
		if type(protectgui) == "function" then
			protectgui(gui)
		end
	end)

	win.Gui = gui

	local holder = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, -338, 0.5, -256),
		Size = UDim2.new(0, 676, 0, 512),
		ZIndex = 100
	}, gui)

	local frame = new("Frame", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 668, 0, 504),
		ZIndex = 102
	}, holder)

	border(frame, 3)
	shadow(holder, UDim2.new(0, 0, 0, 0), frame.Size, SH, 101)

	-- title bar
	local bar = new("Frame", {
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44),
		ZIndex = 103
	}, frame)

	text(bar, {
		Text = string.upper(tostring(cfg.Title or "MUDWOHUB")),
		TextSize = 17,
		TextColor3 = PAPER,
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(0, 340, 1, 0),
		ZIndex = 104
	})

	text(bar, {
		Text = string.upper(tostring(cfg.SubTitle or "")),
		TextSize = 10,
		TextColor3 = Color3.fromRGB(160, 160, 160),
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -268, 0, 0),
		Size = UDim2.new(0, 220, 1, 0),
		ZIndex = 104
	})

	local hide = new("TextButton", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Text = "-",
		Font = FONT,
		TextSize = 18,
		TextColor3 = INK,
		AutoButtonColor = false,
		Position = UDim2.new(1, -42, 0, 9),
		Size = UDim2.new(0, 26, 0, 26),
		ZIndex = 104
	}, bar)

	border(hide, 2)

	-- sidebar
	local side = new("Frame", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 44),
		Size = UDim2.new(0, 160, 1, -44),
		ZIndex = 103
	}, frame)

	solid(side, UDim2.new(1, -3, 0, 0), UDim2.new(0, 0, 0, 0), UDim2.new(0, 3, 0, 0), UDim2.new(0, 0, 1, 0), 105)

	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder
	}, side)

	new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 13)
	}, side)

	-- area de conteudo
	local pages = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 163, 0, 44),
		Size = UDim2.new(1, -163, 1, -44),
		ZIndex = 103
	}, frame)

	win.Holder = holder
	win.Frame = frame
	win.Side = side
	win.Pages = pages

	-- notificacoes
	local nh = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.new(0, 300, 0, 420),
		ZIndex = 401
	}, gui)

	new("UIListLayout", {
		Padding = UDim.new(0, 10),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder
	}, nh)

	win.NotifyHolder = nh

	-- drag
	local dragging = false
	local dragStart
	local startPos

	table.insert(win.Conns, bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = holder.Position
		end
	end))

	table.insert(win.Conns, UIS.InputChanged:Connect(function(input)
		if not dragging then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - dragStart

			holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))

	table.insert(win.Conns, UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	table.insert(win.Conns, UIS.InputBegan:Connect(function(input, busy)
		if busy then
			return
		end

		if cfg.ToggleKey and input.KeyCode == cfg.ToggleKey then
			holder.Visible = not holder.Visible
		end
	end))

	hide.MouseButton1Click:Connect(function()
		holder.Visible = false
	end)

	function win:Notify(nc)
		if self.Destroyed then
			return
		end

		makeNotify(self, nc or {})

		local list = {}

		for _, k in ipairs(self.NotifyHolder:GetChildren()) do
			if k:IsA("Frame") then
				table.insert(list, k)
			end
		end

		if #list > 5 then
			list[1]:Destroy()
		end
	end

	function win:SetAccent(color)
		self.Accent = gray(color)

		for _, p in ipairs(self.Painters) do
			pcall(p)
		end
	end

	function win:GetActiveProfile()
		return self.Profile
	end

	function win:AddTab(tcfg)
		return Tab.create(self, tcfg or {})
	end

	function win:Destroy()
		self.Destroyed = true

		for _, c in ipairs(self.Conns) do
			pcall(function()
				c:Disconnect()
			end)
		end

		self.Conns = {}

		if self.Gui then
			self.Gui:Destroy()
		end
	end

	return win
end

-- ===== persistencia ===================================================

local function ioOk()
	return type(isfile) == "function" and type(readfile) == "function" and type(writefile) == "function"
end

local function enc(v)
	if typeof(v) == "Color3" then
		return {
			__c = { round(v.R * 255), round(v.G * 255), round(v.B * 255) }
		}
	end

	return v
end

local function dec(v)
	if type(v) == "table" and type(v.__c) == "table" then
		return Color3.fromRGB(v.__c[1] or 0, v.__c[2] or 0, v.__c[3] or 0)
	end

	return v
end

function Window:Snapshot()
	local data = {}

	for k, el in pairs(self.Options) do
		if el.Get then
			local ok, v = pcall(el.Get)

			if ok then
				data[k] = enc(v)
			end
		end
	end

	return data
end

function Window:Save()
	if not ioOk() or self.Destroyed then
		return
	end

	pcall(function()
		writefile(self.AutoSave .. "_" .. self.Profile .. ".json", HttpService:JSONEncode(self:Snapshot()))
		writefile(self.AutoSave .. "_meta.json", HttpService:JSONEncode({
			active = self.Profile,
			profiles = self.Profiles
		}))
	end)
end

function Window:QueueSave()
	if self.__saving then
		return
	end

	self.__saving = true

	task.delay(1, function()
		self.__saving = false
		self:Save()
	end)
end

function Window:Load(name)
	if not ioOk() then
		return false
	end

	local file = self.AutoSave .. "_" .. name .. ".json"

	if not isfile(file) then
		return false
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(file))
	end)

	if not ok or type(data) ~= "table" then
		return false
	end

	self.Profile = name
	self:SetConfig(data, false)

	return true
end

function Window:SetConfig(tbl, save)
	if type(tbl) ~= "table" then
		return
	end

	for k, v in pairs(tbl) do
		local el = self.Options[k]

		if el and el.Set then
			pcall(el.Set, dec(v), true)
		end
	end

	if save then
		self:Save()
	end
end

-- ===== tabs ===========================================================

local activeTab = nil

function Tab.create(win, cfg)
	local self = setmetatable({}, Tab)
	self.Window = win
	self.Title = tostring(cfg.Title or "tab")
	self.N = 0

	local page = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = INK,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		ZIndex = 103
	}, win.Pages)

	new("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder
	}, page)

	new("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 24)
	}, page)

	self.Page = page

	local tabSlot = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = win.__tabs and #win.__tabs + 1 or 1,
		ZIndex = 103
	}, win.Side)

	win.__tabs = win.__tabs or {}
	table.insert(win.__tabs, self)

	local btn = new("TextButton", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Text = string.upper(self.Title),
		Font = FONT,
		TextSize = 12,
		TextColor3 = INK,
		AutoButtonColor = false,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -6, 0, 31),
		ZIndex = 105
	}, tabSlot)

	border(btn, 2)

	local sh = shadow(tabSlot, UDim2.new(0, 0, 0, 0), btn.Size, 3, 104)

	local function paint(on)
		btn.BackgroundColor3 = on and INK or PAPER
		btn.TextColor3 = on and PAPER or INK
		sh.Visible = not on
	end

	paint(false)

	local function activate()
		if activeTab and activeTab ~= self then
			activeTab.Page.Visible = false
			activeTab.Paint(false)
		end

		activeTab = self
		page.Visible = true
		paint(true)
	end

	self.Paint = paint

	btn.MouseButton1Click:Connect(activate)

	if win.__tabs and #win.__tabs == 1 then
		activate()
	end

	function self:Activate()
		activate()
	end

	function self:_next()
		self.N = self.N + 1

		return self.N
	end

	return self
end

-- ===== elementos ======================================================

function Tab:AddSection(title)
	local row = slot(self.Page, 30, self:_next())

	text(row, {
		Text = string.upper(tostring(title)),
		TextSize = 13,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 104
	})

	solid(row, UDim2.new(0, 0, 0, 24), UDim2.new(0, 0, 0, 0), UDim2.new(1, -4, 0, 0), UDim2.new(0, 0, 0, 3), 104)

	return row
end

function Tab:AddParagraph(cfg)
	cfg = cfg or {}

	local row = slot(self.Page, 0, self:_next(), true)

	local box = new("Frame", {
		BackgroundColor3 = PAPER2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 104
	}, row)

	border(box, 2)

	local psh = shadow(row, UDim2.new(0, 0, 0, 0), UDim2.new(1, -10, 0, 0), 4, 103)

	box:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		psh.Size = UDim2.new(1, -10, 0, box.AbsoluteSize.Y)
	end)

	solid(box, UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0), UDim2.new(0, 7, 0, 0), UDim2.new(0, 0, 1, 0), 105)

	local pad = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 12),
		Size = UDim2.new(1, -30, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 105
	}, box)

	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder
	}, pad)

	new("UIPadding", {
		PaddingBottom = UDim.new(0, 12)
	}, pad)

	if cfg.Title then
		text(pad, {
			Text = string.upper(tostring(cfg.Title)),
			TextSize = 12,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 1,
			ZIndex = 106
		})
	end

	local body = text(pad, {
		Text = tostring(cfg.Content or ""),
		TextSize = 12,
		TextColor3 = Color3.fromRGB(20, 20, 20),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		ZIndex = 106
	})

	return {
		Set = function(body2)
			body.Text = tostring(body2 or "")
		end
	}
end

function Tab:AddToggle(key, cfg)
	cfg = cfg or {}

	local value = cfg.Default == true
	local descH = cfg.Description and 16 or 0
	local row = slot(self.Page, 26 + descH, self:_next())

	text(row, {
		Text = string.upper(tostring(cfg.Title or key)),
		TextSize = 12,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(1, -62, 0, 16),
		ZIndex = 104
	})

	if cfg.Description then
		text(row, {
			Text = tostring(cfg.Description),
			TextSize = 10,
			TextColor3 = MUTED,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(0, 0, 0, 20),
			Size = UDim2.new(1, -62, 0, 16),
			ZIndex = 104
		})
	end

	local track = new("Frame", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -50, 0, 4),
		Size = UDim2.new(0, 44, 0, 22),
		ZIndex = 105
	}, row)

	border(track, 2)
	shadow(row, UDim2.new(1, -50, 0, 4), track.Size, 3, 104)

	local knob = new("Frame", {
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 3, 0, 3),
		Size = UDim2.new(0, 14, 0, 14),
		ZIndex = 106
	}, track)

	local click = new("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 107
	}, track)

	local el = { Key = key, Value = value }

	local function paint()
		if value then
			local f = fillOf(self.Window.Accent)

			track.BackgroundColor3 = f
			knob.BackgroundColor3 = readable(f)
			knob.Position = UDim2.new(1, -17, 0, 3)
		else
			track.BackgroundColor3 = PAPER
			knob.BackgroundColor3 = INK
			knob.Position = UDim2.new(0, 3, 0, 3)
		end
	end

	el.Set = function(v, silent)
		value = v == true
		el.Value = value
		paint()

		if not silent and cfg.Callback then
			pcall(cfg.Callback, value)
		end
	end
	el.Set = wrapSet(el, el.Set)

	el.Get = function()
		return value
	end

	el.ChangeState = function(a, b)
		-- aceita :ChangeState(v) e .ChangeState(v)
		el.Set(a == el and b or a)
	end

	click.MouseButton1Click:Connect(function()
		el.Set(not value)
		self.Window:QueueSave()
	end)

	paint()
	self.Window.Options[key] = el
	table.insert(self.Window.Painters, paint)

	return el
end

function Tab:AddSlider(key, cfg)
	cfg = cfg or {}

	local min = tonumber(cfg.Min) or 0
	local max = tonumber(cfg.Max) or 100
	local step = tonumber(cfg.Rounding)
	local value = tonumber(cfg.Default) or min

	value = math.max(min, math.min(max, value))

	local descH = cfg.Description and 16 or 0
	local row = slot(self.Page, 46 + descH, self:_next())

	local function fmt(v)
		if step == 0 then
			return tostring(round(v))
		end

		return string.format("%.2f", v)
	end

	text(row, {
		Text = string.upper(tostring(cfg.Title or key)),
		TextSize = 12,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(1, -110, 0, 16),
		ZIndex = 104
	})

	local val = text(row, {
		Text = fmt(value) .. tostring(cfg.Suffix or ""),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -110, 0, 2),
		Size = UDim2.new(0, 104, 0, 16),
		ZIndex = 104
	})

	if cfg.Description then
		text(row, {
			Text = tostring(cfg.Description),
			TextSize = 10,
			TextColor3 = MUTED,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(0, 0, 0, 20),
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 104
		})
	end

	local y = 24 + descH

	local track = new("Frame", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.new(1, -8, 0, 14),
		ZIndex = 105
	}, row)

	border(track, 2)

	local fill = new("Frame", {
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 105
	}, track)

	local knob = new("Frame", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 9, 0, 20),
		ZIndex = 106
	}, track)

	border(knob, 2)

	local el = { Key = key, Value = value }

	local function paint()
		local a = (value - min) / math.max(max - min, 0.0001)

		a = math.max(0, math.min(1, a))
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		val.Text = fmt(value) .. tostring(cfg.Suffix or "")
		el.Value = value
	end

	el.Set = function(v, silent)
		v = tonumber(v) or min

		if step == 0 then
			v = round(v)
		elseif step and step > 0 then
			v = round(v / step) * step
		end

		v = math.max(min, math.min(max, v))

		local changed = v ~= value
		value = v
		paint()

		if changed and not silent and cfg.Callback then
			pcall(cfg.Callback, value)
		end
	end
	el.Set = wrapSet(el, el.Set)

	el.Get = function()
		return value
	end

	local dragging = false

	local function place(input)
		local rel = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)

		el.Set(min + math.max(0, math.min(1, rel)) * (max - min))
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			place(input)
		end
	end)

	table.insert(self.Window.Conns, UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			place(input)
		end
	end))

	table.insert(self.Window.Conns, UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				self.Window:QueueSave()
			end
		end
	end))

	paint()
	self.Window.Options[key] = el

	return el
end

function Tab:AddDropdown(key, cfg)
	cfg = cfg or {}

	local values = cfg.Values or { "" }
	local value = cfg.Default or values[1]
	local descH = cfg.Description and 18 or 0

	local itemH = 28
	local maxH = 170

	local baseH = 22 + descH + 30 + 8
	local row = slot(self.Page, baseH, self:_next())
	local open = false
	local panel
	local el = { Key = key, Value = value, Options = values }

	local function panelH()
		return open and math.min(#values * itemH, maxH) or 0
	end

	local function resize()
		-- abre pra baixo empurrando as linhas seguintes: nunca fica atras de nada
		row.Size = UDim2.new(1, -6, 0, baseH + panelH())
		panel.Size = UDim2.new(1, -10, 0, panelH())
	end

	local function rebuild()
		for _, c in ipairs(panel:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end

		for i, v in ipairs(values) do
			local item = new("TextButton", {
				BackgroundColor3 = PAPER,
				BorderSizePixel = 0,
				Text = tostring(v),
				Font = FONT,
				TextSize = 12,
				TextColor3 = INK,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, itemH),
				LayoutOrder = i,
				AutoButtonColor = false,
				ZIndex = 302
			}, panel)

			new("UIPadding", {
				PaddingLeft = UDim.new(0, 10)
			}, item)

			item.MouseEnter:Connect(function()
				item.BackgroundColor3 = INK
				item.TextColor3 = PAPER
			end)

			item.MouseLeave:Connect(function()
				item.BackgroundColor3 = PAPER
				item.TextColor3 = INK
			end)

			item.MouseButton1Click:Connect(function()
				el.Set(v)
				self.Window:QueueSave()
				open = false
				panel.Visible = false
				resize()
			end)
		end

		resize()
	end

	text(row, {
		Text = string.upper(tostring(cfg.Title or key)),
		TextSize = 12,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 104
	})

	if cfg.Description then
		text(row, {
			Text = tostring(cfg.Description),
			TextSize = 10,
			TextColor3 = MUTED,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(0, 0, 0, 18),
			Size = UDim2.new(1, 0, 0, 18),
			ZIndex = 104
		})
	end

	local y = 22 + descH

	local box = new("TextButton", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.new(1, -10, 0, 30),
		ZIndex = 105
	}, row)

	border(box, 2)
	shadow(row, UDim2.new(0, 0, 0, y), box.Size, 3, 104)

	local label = text(box, {
		Text = tostring(value),
		TextSize = 12,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -36, 1, 0),
		ZIndex = 106
	})

	text(box, {
		Text = "+",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -24, 0, 0),
		Size = UDim2.new(0, 16, 1, 0),
		ZIndex = 106
	})

	panel = new("ScrollingFrame", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, y + 36),
		Size = UDim2.new(1, -10, 0, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = INK,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 300
	}, row)

	border(panel, 2)

	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder
	}, panel)

	rebuild()

	box.MouseButton1Click:Connect(function()
		open = not open
		panel.Visible = open
		resize()
	end)

	el.Set = function(v, silent)
		local changed = tostring(v) ~= tostring(value)

		value = v
		el.Value = v
		label.Text = tostring(v)

		if changed and not silent and cfg.Callback then
			pcall(cfg.Callback, v)
		end
	end
	el.Set = wrapSet(el, el.Set)

	el.Get = function()
		return value
	end

	el.SetValues = function(a, b)
		local t = a == el and b or a

		if type(t) ~= "table" then
			return
		end

		values = t
		el.Options = t
		rebuild()

		local found = false

		for _, v in ipairs(values) do
			if v == value then
				found = true
			end
		end

		if not found and values[1] ~= nil then
			el.Set(values[1])
		end
	end

	self.Window.Options[key] = el

	return el
end

function Tab:AddButton(cfg)
	cfg = cfg or {}

	local descH = cfg.Description and 20 or 0
	local row = slot(self.Page, 58 + descH, self:_next())
	local ghost = cfg.Variant == "ghost"
	local y = 22 + descH

	text(row, {
		Text = string.upper(tostring(cfg.Title or "run")),
		TextSize = 12,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 104
	})

	if cfg.Description then
		text(row, {
			Text = tostring(cfg.Description),
			TextSize = 10,
			TextColor3 = MUTED,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(0, 0, 0, 18),
			Size = UDim2.new(1, 0, 0, 20),
			ZIndex = 104
		})
	end

	local btn = new("TextButton", {
		BackgroundColor3 = ghost and PAPER or INK,
		BorderSizePixel = 0,
		Text = string.upper(tostring(cfg.ButtonText or "run")),
		Font = FONT,
		TextSize = 12,
		TextColor3 = ghost and INK or PAPER,
		AutoButtonColor = false,
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.new(1, -10, 0, 32),
		ZIndex = 105
	}, row)

	border(btn, 2)

	local sh = shadow(row, UDim2.new(0, 0, 0, y), btn.Size, 4, 104)

	btn.MouseButton1Down:Connect(function()
		sh.Visible = false
		btn.Position = UDim2.new(0, 4, 0, y + 4)
	end)

	btn.MouseButton1Up:Connect(function()
		sh.Visible = true
		btn.Position = UDim2.new(0, 0, 0, y)
	end)

	btn.MouseLeave:Connect(function()
		sh.Visible = true
		btn.Position = UDim2.new(0, 0, 0, y)
	end)

	btn.MouseButton1Click:Connect(function()
		if cfg.Callback then
			task.spawn(function()
				local ok, err = pcall(cfg.Callback)

				if not ok then
					warn("[MudwoHub UI] " .. tostring(cfg.Title or "?") .. ": " .. tostring(err))
				end
			end)
		end
	end)

	return { Button = btn, Set = function() end }
end

function Tab:AddColorPicker(key, cfg)
	cfg = cfg or {}

	local value = typeof(cfg.Default) == "Color3" and cfg.Default or PAPER
	local baseH = 34
	local row = slot(self.Page, baseH, self:_next())
	local open = false

	text(row, {
		Text = string.upper(tostring(cfg.Title or key)),
		TextSize = 12,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(1, -88, 0, 18),
		ZIndex = 104
	})

	local swatch = new("TextButton", {
		BackgroundColor3 = value,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.new(1, -78, 0, 2),
		Size = UDim2.new(0, 68, 0, 22),
		ZIndex = 105
	}, row)

	border(swatch, 2)
	shadow(row, UDim2.new(1, -78, 0, 2), swatch.Size, 3, 104)

	local panel = new("Frame", {
		BackgroundColor3 = PAPER2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, -10, 0, 0),
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 300
	}, row)

	border(panel, 2)

	local el = { Key = key, Value = value }
	local channels = { "R", "G", "B" }
	local fills = {}

	local function paint()
		swatch.BackgroundColor3 = value
		el.Value = value

		for i, ch in ipairs(channels) do
			if fills[i] then
				fills[i].Size = UDim2.new(value[ch], 0, 1, 0)
			end
		end
	end

	el.Set = function(v, silent)
		if typeof(v) ~= "Color3" then
			return
		end

		local changed = v ~= value

		value = v
		paint()

		if changed and not silent and cfg.Callback then
			pcall(cfg.Callback, value)
		end
	end
	el.Set = wrapSet(el, el.Set)

	el.Get = function()
		return value
	end

	for i, ch in ipairs(channels) do
		local y = 10 + (i - 1) * 26

		text(panel, {
			Text = ch,
			TextSize = 11,
			Position = UDim2.new(0, 10, 0, y + 2),
			Size = UDim2.new(0, 14, 0, 14),
			ZIndex = 301
		})

		local track = new("Frame", {
			BackgroundColor3 = PAPER,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 30, 0, y + 4),
			Size = UDim2.new(1, -44, 0, 10),
			ZIndex = 301
		}, panel)

		border(track, 1)

		local fill = new("Frame", {
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			ZIndex = 302
		}, track)

		fills[i] = fill

		local function setCh(input)
			local rel = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)

			rel = math.max(0, math.min(1, rel))

			local c = { value.R, value.G, value.B }

			c[i] = rel
			el.Set(Color3.new(c[1], c[2], c[3]))
		end

		local dragging = false

		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setCh(input)
			end
		end)

		table.insert(self.Window.Conns, UIS.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setCh(input)
			end
		end))

		table.insert(self.Window.Conns, UIS.InputEnded:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				dragging = false
				self.Window:QueueSave()
			end
		end))
	end

	swatch.MouseButton1Click:Connect(function()
		open = not open
		panel.Visible = open
		panel.Size = UDim2.new(1, -10, 0, open and 86 or 0)
		row.Size = UDim2.new(1, -6, 0, baseH + (open and 94 or 0))
	end)

	paint()
	self.Window.Options[key] = el

	return el
end

function Tab:AddKeybind(key, cfg)
	cfg = cfg or {}

	local value = cfg.Default or Enum.KeyCode.Unknown
	local row = slot(self.Page, 28, self:_next())

	text(row, {
		Text = string.upper(tostring(cfg.Title or key)),
		TextSize = 12,
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.new(1, -116, 0, 18),
		ZIndex = 104
	})

	local btn = new("TextButton", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Text = value.Name,
		Font = FONT,
		TextSize = 11,
		TextColor3 = INK,
		AutoButtonColor = false,
		Position = UDim2.new(1, -110, 0, 0),
		Size = UDim2.new(0, 104, 0, 26),
		ZIndex = 105
	}, row)

	border(btn, 2)
	shadow(row, UDim2.new(1, -110, 0, 0), btn.Size, 3, 104)

	local el = { Key = key, Value = value }
	local listening = false

	el.Set = function(v, silent)
		value = v
		el.Value = v
		btn.Text = typeof(v) == "EnumItem" and v.Name or tostring(v)

		if not silent and cfg.Callback then
			pcall(cfg.Callback, value)
		end
	end
	el.Set = wrapSet(el, el.Set)

	el.Get = function()
		return value
	end

	btn.MouseButton1Click:Connect(function()
		listening = true
		btn.Text = "..."
	end)

	table.insert(self.Window.Conns, UIS.InputBegan:Connect(function(input, busy)
		if listening and not busy and input.UserInputType == Enum.UserInputType.Keyboard then
			listening = false
			el.Set(input.KeyCode)
			self.Window:QueueSave()
		end
	end))

	self.Window.Options[key] = el

	return el
end

function Tab:AddLabel(cfg)
	cfg = cfg or {}
	local row = slot(self.Page, 20, self:_next())

	text(row, {
		Text = tostring(cfg.Text or cfg.Title or ""),
		TextSize = 11,
		TextColor3 = MUTED,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 104
	})

	return row
end

-- ===== gerenciador de perfil =========================================

function Window:AddProfileManager(tab, cfg)
	cfg = cfg or {}

	local win = self

	tab:AddSection(cfg.Section or "profiles")

	local row = slot(tab.Page, 38, tab:_next())

	local box = new("TextBox", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Text = win.Profile,
		PlaceholderText = "profile name",
		Font = FONT,
		TextSize = 12,
		TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(1, -10, 0, 30),
		ZIndex = 105
	}, row)

	border(box, 2)
	shadow(row, UDim2.new(0, 0, 0, 2), box.Size, 3, 104)

	new("UIPadding", {
		PaddingLeft = UDim.new(0, 10)
	}, box)

	local actions = slot(tab.Page, 36, tab:_next())

	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder
	}, actions)

	local function clean()
		local name = string.gsub(tostring(box.Text or ""), "%s+", "")

		if #name == 0 then
			name = "Padrao"
		end

		return name
	end

	local function add(name)
		for _, n in ipairs(win.Profiles) do
			if n == name then
				return
			end
		end

		table.insert(win.Profiles, name)
	end

	local function mk(label, ghost, onClick)
		local b = new("TextButton", {
			BackgroundColor3 = ghost and PAPER or INK,
			BorderSizePixel = 0,
			Text = label,
			Font = FONT,
			TextSize = 11,
			TextColor3 = ghost and INK or PAPER,
			Size = UDim2.new(0, 104, 0, 30),
			LayoutOrder = #actions:GetChildren(),
			AutoButtonColor = false,
			ZIndex = 105
		}, actions)

		border(b, 2)

		local sh = shadow(actions, UDim2.new(0, 0, 0, 0), b.Size, 3, 104)

		b.MouseButton1Down:Connect(function()
			sh.Visible = false
			b.Position = UDim2.new(0, 3, 0, 3)
		end)

		b.MouseButton1Up:Connect(function()
			sh.Visible = true
			b.Position = UDim2.new(0, 0, 0, 0)
		end)

		b.MouseLeave:Connect(function()
			sh.Visible = true
			b.Position = UDim2.new(0, 0, 0, 0)
		end)

		b.MouseButton1Click:Connect(onClick)

		return b
	end

	mk("SALVAR", false, function()
		local name = clean()

		win.Profile = name
		add(name)
		win:Save()
		win:Notify({
			Title = "profile",
			Content = "saved as " .. name,
			Kind = "success"
		})
	end)

	mk("CARREGAR", false, function()
		local name = clean()

		if win:Load(name) then
			win:Notify({
				Title = "profile",
				Content = "loaded " .. name,
				Kind = "success"
			})
		else
			win:Notify({
				Title = "profile",
				Content = "no profile named " .. name,
				Kind = "error"
			})
		end
	end)

	mk("APAGAR", true, function()
		local name = clean()

		if type(delfile) == "function" then
			pcall(function()
				delfile(win.AutoSave .. "_" .. name .. ".json")
			end)
		end

		for i, n in ipairs(win.Profiles) do
			if n == name then
				table.remove(win.Profiles, i)
				break
			end
		end

		win:Save()
		win:Notify({
			Title = "profile",
			Content = "deleted " .. name,
			Kind = "warning"
		})
	end)

	return row
end

return API
