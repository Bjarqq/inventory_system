-- Discord user: Bjarqq. Roblox user: Bjarqq
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")

local ModuleManager = script.Parent
local ScreenGui = ModuleManager.Parent

-- Configurations/Settings
local Config = {
	HotbarFrame = ScreenGui.Hotbar,
	InventoryFrame = ScreenGui.Inventory.ScrollingFrame,
	HotbarSlots = 8,
	DragCooldown = 0.2,
}

-- Creating a class
local InventoryHandler = {} 
InventoryHandler.__index = InventoryHandler

-- Variables
local allItems = {} -- a list of all Items in the inventoryHandler Class
local hotbarSlots = {} -- slot [X] = false/Item
local draggedItem = nil -- the UIItemButton that is currently being dragged if any
local currentDropSlot = nil -- if draggedItem is dropped this will be the new slot for the item
local canDragItems = true -- if the player can drag items. used as a cooldown
local addToInventorySlot-- hidden slot at the end of the inventory grid.
-- shown while hovering the inventory during a drag

-- Helper functions to setup a slot

-- Clones a HotbarSlot template into SlotParent.
local function addHotbarSlot(SlotParent, number)
	local newHotbarSlot = script.HotbarSlot:Clone()
	newHotbarSlot.Parent = SlotParent
	if number then -- only used for hotbar slots
		newHotbarSlot.PosLabel.Text = tostring(number)
	end
	newHotbarSlot.Visible = true
	return newHotbarSlot
end

-- Data functions

-- finds the first empty hotbar slot starting with slot 1
local function getEmptyHotbarSlot()
	for slotNum, slotItem in pairs(hotbarSlots) do -- [1] = false
		if slotItem == false then
			return slotNum
		end
	end
end

local function getItemByName(name)
	for _, item in ipairs(allItems) do
		if item.ItemName == name then
			return item
		end
	end
end

-- Creates a tween service tween for one property
local function tweenUI(object, property, value, Time)
	local tweeninfo = TweenInfo.new(Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local propertyTable = {[property] = value}
	local tween = tweenService:Create(object, tweeninfo, propertyTable)
	return tween
end

local function setupSlot(Slot)
	Slot.MouseEnter:Connect(function()
		 -- initializes dropping inside the slot
		currentDropSlot = Slot
		if not draggedItem then
			local tween = tweenUI(Slot.ItemButton, "Rotation", 15, 0.15) -- small tilt animation when hovered
			tween:Play()
		end
	end)
	Slot.MouseLeave:Connect(function()
		currentDropSlot = nil
		if not draggedItem then
			local tween = tweenUI(Slot.ItemButton, "Rotation", 0, 0.15)
			tween:Play()
		end
	end)
end
-- Drag and Drop function

local function setupUIItemButton(Item, ItemImageId)
	-- give the slot's itemButton the image
	local ItemButton = Item.UISlot:WaitForChild("ItemButton")
	ItemButton.Image = ItemImageId.Value

	local draggingConnection = nil
	local function startDrag()
		-- checks for draggedItem so if startDrag runs twice, 2 items can't be dragged at once
		if not canDragItems or draggedItem then return end
		-- drag cooldown
		canDragItems = false
		task.delay(Config.DragCooldown, function()
			canDragItems = true
		end)

		draggedItem = Item.UIItemButton
		Item.UIItemButton.Parent = ScreenGui -- change its parent so it isn't stuck in a grid layout

		local function followMouse()
			local mousePos = userInputService:GetMouseLocation()
			Item.UIItemButton.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
		end
		draggingConnection = runService.RenderStepped:Connect(function()
			followMouse()
		end)
		followMouse()
	end

	local function dragStopped()
		-- this system is very dependent on dragStart and dragstop happening in order
		-- the line underneath requires the Item's ItemButton to be currently dragging.
		-- this check prevents all sorts of bugs like e.g the cursor dragging an itemButton 
		-- then twitching out of the dragged button's area and releasing on another
		-- itemButton breaking the dragStart/dragStop sequence for both Items.
		if draggedItem ~= Item.UIItemButton then return end

		if draggingConnection then
			draggingConnection:Disconnect()
			draggingConnection = nil
		end

		draggedItem = nil
		Item.UIItemButton.Parent = Item.UISlot -- change the item's parent back to the slot
		Item.UIItemButton.Position = UDim2.new(0.5, 0, 0.5, 0) -- center in slot
		
		if currentDropSlot == nil then
			-- tween its rotation back to normal
			local tween = tweenUI(Item.UIItemButton, "Rotation", 0, 0.15)
			tween:Play()
			return
		end


		if currentDropSlot.Parent == Config.HotbarFrame then
			-- slots are named numbers 1 through 8. Checks if the slot is available then moves it over
			if hotbarSlots[tonumber(currentDropSlot.Name)] == false then 
				Item:MoveToSlot(currentDropSlot, ItemImageId)
				currentDropSlot = nil
			end
		elseif currentDropSlot.Parent == Config.InventoryFrame then
			-- addToInventorySlot is used as the inventory dropslot
			if currentDropSlot ~= addToInventorySlot then return end
			
			local newSlot = addHotbarSlot(Config.InventoryFrame)
			Item:MoveToSlot(newSlot, ItemImageId)
			addToInventorySlot.Visible = false -- hides the slot so it looks like it was dropped into it
			currentDropSlot = nil	
		end
	end
	Item.FunctionConnections.MouseDown = Item.UIItemButton.MouseButton1Down:Connect(startDrag)
	Item.FunctionConnections.MouseUp = Item.UIItemButton.MouseButton1Up:Connect(dragStopped)
end

function InventoryHandler.AddNewItem(Name, Quantity)
	local ItemImageId = replicatedStorage.ItemImageIds:FindFirstChild(Name) -- stringValue

	if not ItemImageId then
		warn(string.format("Item %q does not exist in ItemImageIds", Name))
		return
	end

	-- jump animation played whenever an item is added or stacked
	local function playNewItemAnimation(Item)
		local tweeninfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
		local propertyTable = {["Size"] = UDim2.fromOffset(100, 100)}
		local tween = tweenService:Create(Item.UIItemButton, tweeninfo, propertyTable)
		tween:Play()
	end
	
	local existingItem = getItemByName(Name)
	if existingItem then
		existingItem.Quantity += Quantity
		existingItem.UISlot.QuantityLabel.Text = "x" .. existingItem.Quantity
		playNewItemAnimation(existingItem)
		return existingItem
	end

	local Item = setmetatable({}, InventoryHandler)
	Item.ItemName = Name
	Item.Quantity = Quantity
	Item.UISlot = nil
	Item.UIItemButton = nil -- the button that is visually used to represent the item dragging
	Item.FunctionConnections = {} -- stores an items connections so they can be disconnected later
	table.insert(allItems, Item)

	local emptyHotbarSlotNum = getEmptyHotbarSlot() -- checks if a hotbar slot is available
	if emptyHotbarSlotNum then
		Item.UISlot = Config.HotbarFrame[tostring(emptyHotbarSlotNum)]
	else
		Item.UISlot = addHotbarSlot(Config.InventoryFrame)
	end
	Item:MoveToSlot(Item.UISlot, ItemImageId)
	playNewItemAnimation(Item)
	
	return Item
end

function InventoryHandler:MoveToSlot(newSlot, ItemImageId)
	
	-- reset old slot to have nothing in it
	local oldSlot = self.UISlot
	oldSlot.QuantityLabel.Text = ""
	if oldSlot ~= newSlot then -- if the item was just created they are both equal
		if oldSlot.Parent == Config.InventoryFrame then
			oldSlot:Destroy()
		elseif oldSlot.Parent == Config.HotbarFrame then
			-- clears the slot in the table so new items can enter
			hotbarSlots[tonumber(oldSlot.Name)] = false
			oldSlot.ItemButton.Image = "" -- Gets rid of the slot's item image
		end
	end
	-- disconnect old ItemButton functions so you can't call startDrag/dragStopped from an empty slot
	for i, Function in self.FunctionConnections do
		Function:Disconnect()
	end
	
	-- newSlot
	newSlot.QuantityLabel.Text = "x" .. self.Quantity
	if newSlot.Parent == Config.HotbarFrame then
		hotbarSlots[tonumber(newSlot.Name)] = self -- Store the item in hotbarSlots table
	end
	
	-- Change all the data over to the newSlot
	self.UISlot = newSlot
	self.UIItemButton = newSlot:WaitForChild("ItemButton")
	setupUIItemButton(self, ItemImageId) -- add image + dragging functions
	setupSlot(newSlot) -- set currentDropSlot + tilt animation when hovered
end
function InventoryHandler:Init()
	addToInventorySlot = addHotbarSlot(Config.InventoryFrame)
	addToInventorySlot.Name = "PreviewSlot"
	addToInventorySlot.Visible = false
	
	for slot = 1, Config.HotbarSlots do -- add all the hotbarslots
		local Slot = addHotbarSlot(Config.HotbarFrame, slot)
		Slot.Name = slot
		hotbarSlots[slot] = false
		setupSlot(Slot)
	end
	
	Config.InventoryFrame.MouseEnter:Connect(function()
		if not draggedItem then return end
		for i, item in allItems do
			-- don't want items from the inventory to be dropable into the inventory again
			if draggedItem == item.UIItemButton and item.UISlot.Parent == Config.InventoryFrame then
				return
			end 
		end
		addToInventorySlot.Visible = true
		addToInventorySlot.LayoutOrder = #Config.InventoryFrame:GetChildren() -- always last
		currentDropSlot = addToInventorySlot
	end)
	Config.InventoryFrame.MouseLeave:Connect(function()
		addToInventorySlot.Visible = false
		currentDropSlot = nil
	end)
	local searchBar = Config.InventoryFrame.Parent.SearchBar -- TextBox
	local function SearchItems()
		for _, item in ipairs(allItems) do
			local itemName = string.lower(item.ItemName)
			local search = string.lower(searchBar.Text)
			item.UISlot.Visible = string.find(itemName, search, 1, true) ~= nil
		end
	end
	searchBar:GetPropertyChangedSignal("Text"):Connect(function()
		SearchItems()
	end)
end

return InventoryHandler