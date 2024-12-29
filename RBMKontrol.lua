local component = require "component"
local term = require "term"
local event = require "event"
local string = require "string"
local computer = require "computer"
 
fuelRods = {}
boilerChannels = {}
controlRods = {}
heaterChannels = {}
irradiationColumns = {}
crane = {}
 
for address, _ in component.list("rbmk_fuel_rod") do
    table.insert(fuelRods, address)
end
 
for address, _ in component.list("rbmk_boiler") do
    table.insert(boilerChannels, address)
end
 
for address, _ in component.list("rbmk_control_rod") do
    table.insert(controlRods, address)
end
 
for address, _ in component.list("rbmk_heater") do
    table.insert(heaterChannels, address)
end
 
for address, _ in component.list("rbmk_outgasser") do
    table.insert(irradiationColumns, address)
end
 
for address, _ in component.list("rbmk_crane") do
    table.insert(crane, address)
end
 
--            .125, .25, .375, .5, .625, .75, .875, 1.0
columnCaps = {"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"}
 
printColors = {0x00FF00, 0x39FF00, 0x71FF00, 0xAAFF00, 0xE3FF00, 0xFFE300, 0xFFAA00, 0xFF7100, 0xFF3900, 0xFF0000}
 
function newGraph(x, y, width, height, name, valueType, valueFunc, maxDisplayValue)
    local graph = {xpos = 0, ypos = 0, width = 0, height = 0, name = "", valueFunc = "", maxDisplayValue = 0}
    graph.xpos = x
    graph.ypos = y
    graph.width = width
    graph.height = height
    graph.name = name
    graph.valueType = valueType
    graph.valueFunc = valueFunc
    graph.maxDisplayValue = maxDisplayValue
    return graph
end
 
function newButton(x, y, width, height, colorUp, colorDown, func)
    local button = {xpos = 0, ypos = 0, width = 0, height = 0, colorUp = 0, colorDown = 0, func = nil}
    button.xpos = x
    button.ypos = y
    button.width = width
    button.height = height
    button.colorUp = colorUp
    button.colorDown = colorDown
    button.func = func
    return button
end
 
function drawButton(button, color)
    component.gpu.setBackground(color)
    component.gpu.fill(button.xpos, button.ypos, button.width, button.height, " ")
    component.gpu.setBackground(0x000000)
end
 
pressedButton = nil
function buttonPress(_, _, x, y, _, _)
    for _, b in pairs(buttons) do
        if((x>=b.xpos) and (x<(b.xpos+b.width)) and (y>=b.ypos) and (y<(b.ypos+b.height)) ) then
            drawButton(b, b.colorDown)
            pressedButton = b
        end
    end
end
 
function buttonRelease(_, _, x, y, _, _)
    drawButton(pressedButton, pressedButton.colorUp)
    pressedButton.func()
    pressedButton = nil
end
 
function drawGraphBox(graph)
    drawBox(graph.xpos, graph.ypos, graph.width, graph.height, graph.name, "header")
end
 
-- type "standard"
-- type "header"
function drawBox(x, y, width, height, title, type)
    text = {}
    offset = 0
    
    -- Top
    text[1] = "┌"
    for i=2,width-1 do
        text[i] = "─"
    end
    text[width] = "┐"
 
    component.gpu.set(x, y, table.concat(text))
    component.gpu.set(x+1, y, title)
 
    -- Sides
    for i=1+offset,height-2 do
        component.gpu.set(x, y+i, "│")
        component.gpu.set(x+width-1, y+i, "│")
    end
 
    -- Bottom
    text[1] = "└"
    for i=2,width-1 do
        text[i] = "─"
    end
    text[width] = "┘"
 
    component.gpu.set(x, y+height-1, table.concat(text))
 
    if(type=="header") then
        text[1] = "├"
 
        for i=2,width-1 do
            text[i] = "─"
        end
 
        text[width] = "┤"
 
        component.gpu.set(x, y+2, table.concat(text))
    end
end
 
-- Helper function for iterateGraph()
function printColumn(x, y, height, value, maxValue, color)
    columnHeight = math.clamp((value/maxValue) * height, 0, height)
    columnY = (height - math.floor(columnHeight))
    capValue = math.fmod(math.floor((columnHeight - math.floor(columnHeight)) * 8), 8) + 1
 
    component.gpu.setBackground(color)
    component.gpu.fill(x, y + columnY, 1, math.floor(columnHeight), " ")
    component.gpu.setBackground(0x000000)
 
    component.gpu.fill(x, y, 1, columnY, " ")
 
    if(columnHeight < height) then
        component.gpu.setForeground(color)
        component.gpu.set(x, y - 1 + columnY, columnCaps[capValue])
        component.gpu.setForeground(0xFFFFFF)
    end
end
 
function iterateGraph(graph)
    x = graph.xpos
    y = graph.ypos
    width = graph.width
    height = graph.height
    func = graph.valueFunc
    maxValue = graph.maxDisplayValue
 
    xBound = x+width-2
    yBound = y+3
    colHeight = height-4
 
    for i=x+2,xBound do
        component.gpu.copy(i, yBound, 1, colHeight, -1, 0)
    end
 
    value = 0.0
 
    if(#graph.valueType ~= 0) then 
        for _, address in pairs(graph.valueType) do
            valueAdd = component.invoke(address, func)
            if(valueAdd ~= "N/A") then
                value = value + valueAdd
            end
        end
 
        value = value / #graph.valueType
 
        printColumn(xBound, yBound, colHeight, value, maxValue, printColors[math.clamp(math.floor((value/maxValue)*10), 1, 10)])
        component.gpu.fill(x+1, y+1, width-2, 1, " ")
        component.gpu.set(x+1, y+1, tostring(value))
 
    else
        component.gpu.fill(x+1, y+1, width-2, 1, " ")
        component.gpu.set(x+1, y+1, "N/A")
    end
end
 
function math.clamp(n, low, high) 
    return math.min(math.max(n, low), high) 
end
 
keyInputOffset = 0
lineOffset = 0
keyInputTable = {}
function keyInput(_, _, character, code, _)
    event.ignore("key_down", keyInput)
 
    if(code == 28) then
        result = table.concat(keyInputTable)
        component.gpu.set(2+keyInputOffset, 8+lineOffset, " : " .. result)
        state = result
        stateShift = true
        lineOffset = lineOffset + 1
 
        keyInputOffset = 0
        keyInputTable = {}
 
    else
        table.insert(keyInputTable, string.char(character))
        keyInputOffset = keyInputOffset + 1
        component.gpu.set(1+keyInputOffset, 8+lineOffset, string.char(character))
    end
 
    event.listen("key_down", keyInput)
end
 
function clearPage()
    component.gpu.fill(1,14,160,50," ")
end
 
clearPage()
 
-- Nootles RBMKontrol
title = {   " _   _             _   _             ____  ____  __  __ _  __           _             _ ",
            "| \\ | | ___   ___ | |_| | ___  ___  |  _ \\| __ )|  \\/  | |/ /___  _ __ | |_ _ __ ___ | |",
            "|  \\| |/ _ \\ / _ \\| __| |/ _ \\/ __| | |_) |  _ \\| |\\/| | ' // _ \\| '_ \\| __| '__/ _ \\| |",
            "| |\\  | (_) | (_) | |_| |  __/\\__ \\ |  _ <| |_) | |  | | . \\ (_) | | | | |_| | | (_) | |",
            "|_| \\_|\\___/ \\___/ \\__|_|\\___||___/ |_| \\_\\____/|_|  |_|_|\\_\\___/|_| |_|\\__|_|  \\___/|_|"}
 
for i=1,#(title) do
    component.gpu.set(1,i,title[i])
end
 
categories = {"Summary", "Fuel", "Boilers", "Control", "Heaters", "Irrad", "Crane", "EXIT"}
 
drawBox(1, 7, 159, 7, "Navigation", "header")
for i,c in pairs(categories) do
    component.gpu.set(2+(i-1)*13, 8, categories[i])
end
 
component.gpu.set(149, 8, "SCRAM")
 
buttons = {}
 
buttons[1] = newButton(2,   10, 10, 3, 0xFFFFFF, 0xAAAAAA, function() if(state ~= "summary") then state = "summary" stateShift = true end end)
buttons[2] = newButton(15,  10, 10, 3, 0xFFFFFF, 0xAAAAAA, function() if(state ~= "fuel")    then state = "fuel"     stateShift = true end end)
buttons[3] = newButton(28,  10, 10, 3, 0xFFFFFF, 0xAAAAAA, function() if(state ~= "boilers") then state = "boilers"  stateShift = true end end)
buttons[4] = newButton(41,  10, 10, 3, 0xFFFFFF, 0xAAAAAA, function() if(state ~= "control") then state = "control"  stateShift = true end end)
buttons[5] = newButton(54,  10, 10, 3, 0xFFFFFF, 0xAAAAAA, function() if(state ~= "heaters") then state = "heaters"  stateShift = true end end)
buttons[6] = newButton(67,  10, 10, 3, 0xFFFFFF, 0xAAAAAA, function() if(state ~= "irrad")   then state = "irrad"    stateShift = true end end)
buttons[7] = newButton(80,  10, 10, 3, 0xFFFFFF, 0xAAAAAA, function() if(state ~= "crane")   then state = "crane"    stateShift = true end end)
buttons[8] = newButton(93,  10, 10, 3, 0xFF0000, 0xAA0000, function() state = nil stateShift = true end)
buttons[9] = newButton(149, 10, 10, 3, 0xFF0000, 0xAA0000, function() for _, address in pairs(controlRods) do component.invoke(address, "setLevel", 0) end end)
 
state = "summary"
stateShift = false
 
summaryGraphs = {}
 
summaryGraphs[1] = newGraph(1, 14, 53, 10, "Avg Fuel Rod Heat", fuelRods, "getHeat", 1500)
summaryGraphs[2] = newGraph(54, 14, 53, 10, "Avg Fuel Rod Skin Heat", fuelRods, "getSkinHeat", 1500)
summaryGraphs[3] = newGraph(107, 14, 53, 10, "Avg Control Rod Extension", controlRods, "getLevel", 100)
summaryGraphs[4] = newGraph(1, 24, 53, 10, "Avg Fuel Depletion", fuelRods, "getDepletion", 100)
summaryGraphs[5] = newGraph(54, 24, 53, 10, "Avg Fuel Rod Xenon Poisoning", fuelRods, "getXenonPoison", 100)
summaryGraphs[6] = newGraph(107, 24, 53, 10, "Avg Boiler Heat", boilerChannels, "getHeat", 100)
 
fuelGraphs = {}
 
fuelGraphs[1] = newGraph(1, 14, 53, 10, "Avg Fuel Rod Heat", fuelRods, "getHeat", 1500)
fuelGraphs[2] = newGraph(54, 14, 53, 10, "Avg Fuel Rod Skin Heat", fuelRods, "getSkinHeat", 1500)
fuelGraphs[3] = newGraph(107, 14, 53, 10, "Avg Fuel Rod Core Heat", fuelRods, "getCoreHeat", 10000)
fuelGraphs[4] = newGraph(1, 24, 53, 10, "Avg Fuel Depletion", fuelRods, "getDepletion", 100)
fuelGraphs[5] = newGraph(54, 24, 53, 10, "Avg Fuel Rod Xenon Poisoning", fuelRods, "getXenonPoison", 100)
fuelGraphs[6] = newGraph(107, 24, 53, 10, "Avg Fuel Rod Slow Flux", fuelRods, "getFluxSlow", 100)
 
boilerGraphs = {}
 
boilerGraphs[1] = newGraph(1, 14, 53, 10, "Avg Boiler Heat", boilerChannels, "getHeat", 1500)
boilerGraphs[2] = newGraph(54, 14, 53, 10, "Avg Steam Amount", boilerChannels, "getSteam", 1000000)
boilerGraphs[3] = newGraph(107, 14, 53, 10, "Avg Water Level", boilerChannels, "getWater", 10000)
 
controlGraphs = {}
 
controlGraphs[1] = newGraph(1, 14, 53, 10, "Avg Rod Heat", controlRods, "getHeat", 1500)
controlGraphs[2] = newGraph(54, 14, 53, 10, "Avg Control Rod Extension", controlRods, "getLevel", 100)
controlGraphs[3] = newGraph(107, 14, 53, 10, "Avg Control Rod Target Level", controlRods, "getTargetLevel", 100)
 
heaterGraphs = {}
 
heaterGraphs[1] = newGraph(1, 14, 53, 10, "Avg Heater Heat", heaterChannels, "getHeat", 1500)
heaterGraphs[2] = newGraph(54, 14, 53, 10, "Avg Heater Fluid Level", heaterChannels, "getFill", 16000)
heaterGraphs[3] = newGraph(107, 14, 53, 10, "Avg Heater Fluid Output", heaterChannels, "getExport", 16000)
 
irradGraphs = {}
 
irradGraphs[1] = newGraph(1, 14, 53, 10, "Avg Gas Amount", irradiationColumns, "getGas", 64000)
irradGraphs[2] = newGraph(54, 14, 53, 10, "Avg Progress", irradiationColumns, "getProgress", 100)
 
-- event.listen("key_down", keyInput)
event.listen("touch", buttonPress)
event.listen("drop", buttonRelease)
 
while(true) do
    clearPage()
    stateShift = false
 
    for _, b in pairs(buttons) do
        drawButton(b, b.colorUp)
    end
 
    if(state == "summary") then
        for _, g in pairs(summaryGraphs) do
            drawGraphBox(g)
        end
 
        while(not stateShift) do
            for _, g in pairs(summaryGraphs) do
                iterateGraph(g)
            end
 
            os.sleep(0.25)
        end
 
    elseif(state == "fuel") then
        for _, g in pairs(fuelGraphs) do
            drawGraphBox(g)
        end
 
        while(not stateShift) do
            for _, g in pairs(fuelGraphs) do
                iterateGraph(g)
            end
 
            os.sleep(0.25)
        end
 
    elseif(state == "boilers") then
        drawBox(1, 24, 159, 7, "Set Steam Type", "header")
 
        commandCategories = {"Standard", "Dense", "Super Dense", "Ultra Dense", "Current"}
 
        for i,c in pairs(commandCategories) do
            component.gpu.set(2+(i-1)*13, 25, commandCategories[i])
        end
 
        buttons[10] = newButton(2,  27, 10, 3, 0xFFFFFF, 0xAAAAAA, function() for _, address in pairs(boilerChannels) do component.invoke(address, "setSteamType", 0) end component.gpu.setBackground(0xFFFFFF) component.gpu.fill(54, 27, 10, 3, " ") component.gpu.setBackground(0x000000) end)
        buttons[11] = newButton(15, 27, 10, 3, 0xFFC9C9, 0xAA8686, function() for _, address in pairs(boilerChannels) do component.invoke(address, "setSteamType", 1) end component.gpu.setBackground(0xFFC9C9) component.gpu.fill(54, 27, 10, 3, " ") component.gpu.setBackground(0x000000) end)
        buttons[12] = newButton(28, 27, 10, 3, 0xFF7F7F, 0xAA5555, function() for _, address in pairs(boilerChannels) do component.invoke(address, "setSteamType", 2) end component.gpu.setBackground(0xFF7F7F) component.gpu.fill(54, 27, 10, 3, " ") component.gpu.setBackground(0x000000) end)
        buttons[13] = newButton(41, 27, 10, 3, 0xFF4242, 0xAA2C2C, function() for _, address in pairs(boilerChannels) do component.invoke(address, "setSteamType", 3) end component.gpu.setBackground(0xFF4242) component.gpu.fill(54, 27, 10, 3, " ") component.gpu.setBackground(0x000000) end)
 
        for _, b in pairs(buttons) do
            drawButton(b, b.colorUp)
        end
 
        for _, g in pairs(boilerGraphs) do
            drawGraphBox(g)
        end
 
        while(not stateShift) do
            for _, g in pairs(boilerGraphs) do
                iterateGraph(g)
            end
 
            os.sleep(0.25)
        end
 
        buttons[10], buttons[11], buttons[12], buttons[13] = nil
 
    elseif(state == "control") then
        drawBox(1, 24, 159, 7, "Control Commands", "header")
 
        commandCategories = {"Raise By 1", "Raise By 10", "Lower By 1", "Lower By 10", "Set Red", "Set Yellow", "Set Green", "Set Blue", "Set Purple", "Set All", "Current Group"}
 
        for i,c in pairs(commandCategories) do
            component.gpu.set(2+(i-1)*13, 25, commandCategories[i])
        end
 
        selectedRods = {}
 
        buttons[10] = newButton(2,  27, 10, 3, 0xFFFFFF, 0xAAAAAA, function() for _, address in pairs(selectedRods) do component.invoke(address, "setLevel", component.invoke(address, "getLevel") + 1) end end)
        buttons[11] = newButton(15, 27, 10, 3, 0xFFFFFF, 0xAAAAAA, function() for _, address in pairs(selectedRods) do component.invoke(address, "setLevel", component.invoke(address, "getLevel") + 10) end end)
        buttons[12] = newButton(28, 27, 10, 3, 0xFFFFFF, 0xAAAAAA, function() for _, address in pairs(selectedRods) do component.invoke(address, "setLevel", component.invoke(address, "getLevel") - 1) end end)
        buttons[13] = newButton(41, 27, 10, 3, 0xFFFFFF, 0xAAAAAA, function() for _, address in pairs(selectedRods) do component.invoke(address, "setLevel", component.invoke(address, "getLevel") - 10) end end)
        buttons[14] = newButton(54, 27, 10, 3, 0xFF0000, 0xAA0000, function() selectedRods = {} for _, address in pairs(controlRods) do if(component.invoke(address, "getColor") == "RED") then table.insert(selectedRods, address) end end component.gpu.setBackground(0xFF0000) component.gpu.fill(132, 27, 10, 3, " ") component.gpu.setBackground(0x000000) end)
        buttons[15] = newButton(67, 27, 10, 3, 0xFFFF00, 0xAAAA00, function() selectedRods = {} for _, address in pairs(controlRods) do if(component.invoke(address, "getColor") == "YELLOW") then table.insert(selectedRods, address) end end component.gpu.setBackground(0xFFFF00) component.gpu.fill(132, 27, 10, 3, " ") component.gpu.setBackground(0x000000) end)
        buttons[16] = newButton(80, 27, 10, 3, 0x00FF00, 0x00FF00, function() selectedRods = {} for _, address in pairs(controlRods) do if(component.invoke(address, "getColor") == "GREEN") then table.insert(selectedRods, address) end end component.gpu.setBackground(0x00FF00) component.gpu.fill(132, 27, 10, 3, " ") component.gpu.setBackground(0x000000) end)
        buttons[17] = newButton(93, 27, 10, 3, 0x0000FF, 0x0000AA, function() selectedRods = {} for _, address in pairs(controlRods) do if(component.invoke(address, "getColor") == "BLUE") then table.insert(selectedRods, address) end end component.gpu.setBackground(0x0000FF) component.gpu.fill(132, 27, 10, 3, " ") component.gpu.setBackground(0x000000) end)
        buttons[18] = newButton(106, 27, 10, 3, 0x9900FF, 0x4400AA, function() selectedRods = {} for _, address in pairs(controlRods) do if(component.invoke(address, "getColor") == "PURPLE") then table.insert(selectedRods, address) end end component.gpu.setBackground(0x9900FF) component.gpu.fill(132, 27, 10, 3, " ") component.gpu.setBackground(0x000000) end)
        buttons[19] = newButton(119, 27, 10, 3, 0xFFFFFF, 0xAAAAAA, function() selectedRods = controlRods component.gpu.setBackground(0xFFFFFF) component.gpu.fill(132, 27, 10, 3, " ") component.gpu.setBackground(0x000000) end)
 
        for _, b in pairs(buttons) do
            drawButton(b, b.colorUp)
        end
 
        for _, g in pairs(controlGraphs) do
            drawGraphBox(g)
        end
 
        while(not stateShift) do
            for _, g in pairs(controlGraphs) do
                iterateGraph(g)
            end
 
            os.sleep(0.25)
        end
 
        buttons[10], buttons[11], buttons[12], buttons[13], buttons[14], buttons[15], buttons[16], buttons[17], buttons[18], buttons[19] = nil
 
    elseif(state == "heaters") then
        for _, g in pairs(heaterGraphs) do
            drawGraphBox(g)
        end
 
        while(not stateShift) do
            for _, g in pairs(heaterGraphs) do
                iterateGraph(g)
            end
 
            os.sleep(0.25)
        end
 
    elseif(state == "irrad") then
        for _, g in pairs(irradGraphs) do
            drawGraphBox(g)
        end
 
        while(not stateShift) do
            for _, g in pairs(irradGraphs) do
                iterateGraph(g)
            end
 
            os.sleep(0.25)
        end
 
    elseif(state == "crane") then
        drawBox(1, 14, 38, 13, "Controls", "standard")
        drawBox(39, 14, 20, 3, "Depletion", "standard")
        drawBox(39, 17, 20, 3, "Xenon Poisoning", "standard")
 
        buttons[10] = newButton(15, 15, 10, 3, 0xFFFFFF, 0xAAAAAA, function() for i=1,20 do component.proxy(crane[1]).move("up") end end)
        buttons[11] = newButton(2,  19, 10, 3, 0xFFFFFF, 0xAAAAAA, function() for i=1,20 do component.proxy(crane[1]).move("left") end end)
        buttons[12] = newButton(15, 19, 10, 3, 0xFFFFFF, 0xAAAAAA, function() for i=1,20 do component.invoke(crane[1], "load") end os.sleep(1.5) end)
        buttons[13] = newButton(28, 19, 10, 3, 0xFFFFFF, 0xAAAAAA, function() for i=1,20 do component.proxy(crane[1]).move("right") end end)
        buttons[14] = newButton(15, 23, 10, 3, 0xFFFFFF, 0xAAAAAA, function() for i=1,20 do component.proxy(crane[1]).move("down") end end)
 
        for _, b in pairs(buttons) do
            drawButton(b, b.colorUp)
        end
 
        while(not stateShift) do
            component.gpu.fill(40, 15, 18, 1, " ")
            component.gpu.fill(40, 18, 18, 1, " ")
 
            for _,g in pairs(crane) do
                component.gpu.set(40, 15, tostring(component.invoke(crane[1], "getDepletion")))
                component.gpu.set(40, 18, tostring(component.invoke(crane[1], "getXenonPoison")))
            end
        
            os.sleep(0.25)
        end
 
        buttons[10], buttons[11], buttons[12], buttons[13], buttons[14] = nil
 
    else
        break
    end
end
 
term.clear()
event.ignore("touch", buttonPress)
event.ignore("drop", buttonRelease)
