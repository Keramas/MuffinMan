_addon.name = 'MuffinMan'
_addon.author = 'Kunel'
_addon.version = '1.1'
_addon.commands = {'muffinman','mm'}

require('chat')
require('logger')
packets = require('packets')
res = require('resources')

local webhook_url = "ADD YOUR WEBHOOK HERE"

local https = require("ssl.https")
local ltn12 = require("ltn12")
package.path = package.path .. ';' .. windower.addon_path .. 'libs/?.lua'
local json = require('dkjson')

local push_to_discord = false

local gallimaufry_total = 0
local fight_start_time = nil
local fight_end_time = nil
local party_jobs = {}

local aminon_rolls = {
    ['Tactician\'s'] = {lucky = false, value = 0},
    ['Miser\'s'] =     {lucky = false, value = 0} 
}

local wild_card_roll = 0

-----------------------------
-- Objective and NM tracking
-----------------------------
local mini_log = T{}
local flan_log = T{}
local basement_mini_nms = S{
    'Botulus',
    'Ixion',
    'Naraka',
    'Tulittia'
}
local aurum_chest = false
local naaks = 0
------------------------------

-- Format numbers with commas
local function comma_value(n)
    local left, num, right = tostring(n):match('^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

-- Timestamp for file naming
local function get_timestamp()
    return os.date('%Y-%m-%d_%H-%M-%S')
end

-- Populate job data for party members
function update_job_info(name, main_job_id, main_lvl, sub_job_id, sub_lvl)
    local job_mapping = {
        [1] = 'WAR', [2] = 'MNK', [3] = 'WHM', [4] = 'BLM', [5] = 'RDM', [6] = 'THF',
        [7] = 'PLD', [8] = 'DRK', [9] = 'BST', [10] = 'BRD', [11] = 'RNG', [12] = 'SAM',
        [13] = 'NIN', [14] = 'DRG', [15] = 'SMN', [16] = 'BLU', [17] = 'COR', [18] = 'PUP',
        [19] = 'DNC', [20] = 'SCH', [21] = 'GEO', [22] = 'RUN'
    }

    party_jobs[name] = {
        main = job_mapping[main_job_id] or tostring(main_job_id),
        main_lvl = main_lvl or '?',
        sub = job_mapping[sub_job_id] or tostring(sub_job_id),
        sub_lvl = sub_lvl or '?',
    }
end

-- Format all job data from the party members
local function format_party_composition()
    local lines = { "[Party Composition]" }

    for name, info in pairs(party_jobs) do
        local main = info.main ~= 0 and info.main or '??'
        local main_lvl = info.main_lvl ~= 0 and info.main_lvl or '??'
        local sub = info.sub ~= 0 and info.sub or '??'
        local sub_lvl = info.sub_lvl ~= 0 and info.sub_lvl or '??'

        table.insert(lines, string.format('%s (%s%s/%s%s)', name, main, main_lvl, sub, sub_lvl))
    end

    return lines
end


local function check_basement_minis(mini_name)

    mini_log = T{}
    mini_log:clear()
    
    mini_capturing = true
  
    windower.send_command('scoreboard filter add ' .. mini_name)
    coroutine.sleep(0.5)
    windower.send_command('scoreboard stat wsavg')
    coroutine.sleep(2) 
    windower.send_command('scoreboard filter clear')
    mini_capturing = false

    for _,line in ipairs(mini_log) do
        if line:find(mini_name) then
            return true
        end
    end
    return false
end

local function check_flans()

    flan_log = T{}
    flan_log:clear()
    
    flan_capturing = true
  
    windower.send_command('scoreboard filter add Flan')
    coroutine.sleep(0.5)
    windower.send_command('scoreboard stat wsavg')
    coroutine.sleep(2) 
    windower.send_command('scoreboard filter clear')
    flan_capturing = false

    for _,line in ipairs(flan_log) do
        if line:find("Flan") then
            return true
        end
    end
    return false
end

-- Format Aminon report block
local function format_aminon_report(lines)
    local formatted = {}

    for _, line in ipairs(lines) do
        -- Remove leading "(Name)" prefix
        line = line:gsub("^%([^%)]+%)%s*", "")
        -- Remove "Damage:" if present at the beginning
        line = line:gsub("^Damage:%s*", "")

        -- Iterate over each comma-separated entry
        for entry in line:gmatch("[^,]+") do
            entry = entry:match("^%s*(.-)%s*$") -- trim whitespace

            -- Match: Name 123456(12.3%)
            local name, dmg, pct = entry:match("^(.-)%s+(%d+)%(([%d%.]+)%%%)$")
            if name and dmg and pct then
                table.insert(formatted, { name = name, dmg = tonumber(dmg), pct = pct })
            end
        end
    end

    -- Sort by descending damage
    table.sort(formatted, function(a, b) return a.dmg > b.dmg end)

    local results = { string.format("%-20s %-12s %s", "Name", "Damage", "Percent") }
    for _, entry in ipairs(formatted) do
        table.insert(results, string.format("%-20s %-12s %s%%", entry.name, comma_value(entry.dmg), entry.pct))
    end

    return results
end

-- Format WSAVG block
local function format_wsavg(lines)
    local entries = {}

    for _, line in ipairs(lines) do
        local name, avg, count = line:match("^SB:%s*(.-)%s+(%d+)%s+%((%d+)s%)")
        if name and avg and count and not name:lower():find('skillchain') then
            table.insert(entries, {
                name = name,
                avg = tonumber(avg),
                count = tonumber(count)
            })
        end
    end

    -- Sort by WS Avg descending
    table.sort(entries, function(a, b)
        return a.avg > b.avg
    end)

    -- Format header and rows
    local results = { string.format("%-15s %-10s %s", "Name", "WS Avg", "Count") }
    for _, e in ipairs(entries) do
        table.insert(results, string.format("%-15s %-10s %d", e.name, comma_value(e.avg), e.count))
    end

    return results
end

-- Save full report to file
local function save_report_file(contents)
    local filename = string.format('sortie_%s.txt', get_timestamp())
    local path = windower.addon_path .. 'data/' .. filename

    local f = io.open(path, 'w')
    if f then
        f:write(table.concat(contents, '\n'))
        f:close()
        windower.add_to_chat(207, ('[MuffinMan] Report saved to: data/%s'):format(filename))
    else
        windower.add_to_chat(123, '[MuffinMan] Failed to write sortie report file.')
    end
end



local function send_to_discord(message)

    if type(message) == "table" then
        message = table.concat(message, "\n")
    elseif type(message) ~= "string" then
        windower.add_to_chat(123, "[Discord] Invalid message type: " .. type(message))
        return
    end

    local formatted = '```\n' .. message .. '\n```'
    
    local payload_table = {
        content = formatted
    }

    local payload = json.encode(payload_table)

    local response_body = {}
    local https = require("ssl.https")
    local result, status_code, headers, status_line = https.request{
        url = webhook_url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#payload)
        },
        source = ltn12.source.string(payload),
        sink = ltn12.sink.table(response_body)
    }

    if status_code == 204 then
        windower.add_to_chat(207, "[Discord] Message sent successfully.")
    else
        windower.add_to_chat(123, "[Discord] Failed to send: " .. (status_line or "Unknown error"))
    end
end

---------------------------------------------------
-- Main report generation function
---------------------------------------------------
local function generate_report()
    output_log = T{}
    scoreboard_capturing = true
  
    windower.send_command('scoreboard filter add Aminon')
    coroutine.sleep(0.5)
    windower.send_command('scoreboard report')
    coroutine.sleep(2.5) -- let Scoreboard print its damage lines
    windower.send_command('scoreboard stat wsavg')
    coroutine.sleep(2) -- let Scoreboard print its wsavg lines
    windower.send_command('scoreboard filter clear')
    coroutine.sleep(2)
    scoreboard_capturing = false

    -- Post-process the captured log into report sections
    local aminon_block = {}
    local wsavg_block = {}

    for _, line in ipairs(output_log) do
        if line:find('%(.-%%%)') then
            table.insert(aminon_block, line)
        elseif line:match("^SB: ") then
            table.insert(wsavg_block, line)
        end
    end

    -- Build out the full report
    local report_output = {}

    table.insert(report_output, ('[Sortie Report - %s]'):format(os.date()))
    table.insert(report_output, ('Total Gallimaufry: %s'):format(comma_value(gallimaufry_total)))
    table.insert(report_output, "-----------------------------")

    -- Add extra objectives here
    table.insert(report_output, '[Completed Bonus Objectives]')

    -- Ground Floor Aurum Chest 
    if aurum_chest then
        table.insert(report_output, 'Ground floor Aurum Chest')
    end
    
    -- Basement Minis
    for mob in basement_mini_nms:it() do
        if check_basement_minis(mob) then
            table.insert(report_output, mob)
        end
    end

    -- Flans
    if check_flans() then
        table.insert(report_output, 'Flans')
    end

    -- Naaks chest (increment up from 0 to check if multiple groups/chests done)
    if naaks > 0 then
        table.insert(report_output, ('Naakual sets defeated: %s'):format(comma_value(naaks)))
    end  
    table.insert(report_output, "-----------------------------")
    
    -- Add party composition to report
    for _, line in ipairs(format_party_composition()) do
        table.insert(report_output, line)
    end
    table.insert(report_output, "-----------------------------")


    -- Add COR roll data
    table.insert(report_output, '[COR Rolls]')
    roll_data = ''
    for roll_name, data in pairs(aminon_rolls) do
        if data.lucky then
            roll_data = roll_name .. ': ' .. data.value .. ' (Lucky!)'
        else
            roll_data = roll_name .. ': ' .. data.value
        end
        table.insert(report_output, roll_data)
    end
    table.insert(report_output, "Wild Card: " .. wild_card_roll)
    table.insert(report_output, "-----------------------------")


    -- Add aminon dmg report
    table.insert(report_output, '[Aminon Damage Report]')
    for _, l in ipairs(format_aminon_report(aminon_block)) do table.insert(report_output, l) end
    table.insert(report_output, '-----------------------------')
    table.insert(report_output, '[Aminon Weaponskill Averages]')
    for _, l in ipairs(format_wsavg(wsavg_block)) do table.insert(report_output, l) end

    -- Add Aminon fight duration data to report
    if fight_start_time and fight_end_time then
        local duration = os.difftime(fight_end_time, fight_start_time)
        local minutes = math.floor(duration / 60)
        local seconds = duration % 60
        table.insert(report_output, '-----------------------------')
        table.insert(report_output, "[Aminon Fight Duration]")
        table.insert(report_output, string.format("%d min %d sec", minutes, seconds))
    else
        table.insert(report_output, '-----------------------------')
        table.insert(report_output, "[Aminon Fight Duration] Incomplete or missing.")
    end

    windower.send_command('scoreboard filter clear')

    save_report_file(report_output)

    if push_to_discord then
        send_to_discord(report_output)
    end

end


------------------------------------------------------------------------
-- All event handlers --
------------------------------------------------------------------------
-- Decode party member data from incoming packet 0x0DD
windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)

    if id == 0xDF then  -- Character update (0xDF)
        local packet = packets.parse('incoming', data)
        if packet then
            local playerId = packet['ID']
            if playerId and playerId > 0 then
              
                -- Get player name from ID
                local mob = windower.ffxi.get_mob_by_id(playerId)
                if mob and mob.name then
                    update_job_info(mob.name, packet['Main job'], packet['Main job level'], 
                                  packet['Sub job'], packet['Sub job level'])
                end
            end
        end
        
    elseif id == 0xDD then  -- Party member update (0xDD)
        local packet = packets.parse('incoming', data)
        if packet then
            local name = packet['Name']
            local playerId = packet['ID']
            if name and playerId and playerId > 0 then
                
                update_job_info(name, packet['Main job'], packet['Main job level'], 
                              packet['Sub job'], packet['Sub job level'])
            end
        end
    end

end)


-- Find roll values during Aminon battle
-- Referenced and used code from the 'rolltracker' add-on. Thanks!
windower.register_event('action', function(act)
    
    local rollInfoTemp = {

        -- For Aminon we only care about Tact/Miser
        ['Miser\'s'] =      {30,50,70,90,200,110,20,130,150,170,250,'0',' Save TP',5,7, 15,{nil,0}},
        ['Tactician\'s'] =  {10,10,10,10,30,10,10,0,20,20,40,'-10',' Regain',5,8, 2,{nil,0},{5, 11100, 26930, 26931, 10}},     
    }

    rollInfo = {}
    for key, val in pairs(rollInfoTemp) do
        rollInfo[res.job_abilities:with('english', key .. ' Roll').id] = {key, unpack(val)}
    end    
    
    local wildcard_table = {
        [435] = '1',
        [436] = '2',
        [437] = '3',
        [438] = '4',
        [439] = '5',
        [440] = '6',
    }

    -- This SHOULD be contrained to party members only, but since the logic is only when Aminon is being fought
    -- there is no real need to do that here.
    if fight_start_time then 

        -- For wild card parsing
        if act.category == 6 and act.param == 96 then -- WC ID
            if wildcard_table[act.targets[1].actions[1].message] then
                wild_card_roll = wildcard_table[act.targets[1].actions[1].message]
            else
                wild_card_roll = "Unknown"
            end
        end

        -- For tact/miser parsing
        if act.category == 6 and table.containskey(rollInfo, act.param) then

            local rollID = act.param
            local rollNum = act.targets[1].actions[1].param


            for roll_name, data in pairs(aminon_rolls) do
                if rollInfo[rollID][1] == roll_name then
                    if rollNum == rollInfo[rollID][15] or rollNum == 11 then               
                        aminon_rolls[roll_name].lucky = true
                    end
                    aminon_rolls[roll_name].value = rollNum
                end    
            end

         end
    end
end)


-- Hook Scoreboard's outgoing text so we can capture reports
windower.register_event('outgoing text', function(original, modified, mode)
end)

-- Capture lines printed to chat (Scoreboard outputs reports here)
windower.register_event('incoming text', function(original, modified, mode)
    if scoreboard_capturing then
        table.insert(output_log, original)
    end
    if mini_capturing then
        table.insert(mini_log, original)
    end 
    if flan_capturing then
        table.insert(flan_log, original)
    end

end)


-- Event to detect incoming text for tracking.
windower.register_event('incoming text', function(original, modified, mode)


    -- Look for the start of battle 
    if not fight_start_time then
        local lowered = original:lower()
        if lowered:find("flash") and lowered:find("aminon") then
            fight_start_time = os.time()
            windower.add_to_chat(207, ('[MuffinMan] Fight start detected at %s'):format(os.date('%X', fight_start_time)))
        end
    end

    -- Look for end of the battle
    if original:lower():match('defeats.+aminon') then
        fight_end_time = os.time()
        local duration = os.difftime(fight_end_time, fight_start_time or fight_end_time)
        windower.add_to_chat(207, ('[MuffinMan] Fight ended after %d seconds.'):format(duration))
    end
    

    if mode == 121 or mode == 123 or mode == 10 or mode == 12 or mode == 13 or mode == 14 or mode == 5 then
       
        -- Clean control codes from the incoming line
        local cleaned_line = original:gsub('\30[%d%a]', ''):gsub('\31', ''):gsub('[\r\n]', '')
        
        -- Match player name and gallimaufry amount with according to the in-game text pattern
        local player_name, amount = cleaned_line:match("([%a%-']+)%s+received%s+(%d+)%s+gallimaufry%s+for%s+a%s+total%s+of%s+%d+%.*")

        if player_name and amount then
            gallimaufry_total = gallimaufry_total + tonumber(amount)
            windower.add_to_chat(207, ('[MuffinMan] Received %s gallimaufry. Total: %s'):format(
                comma_value(amount),
                comma_value(gallimaufry_total)
            ))

            -- Check if opened Aurum chest
            if tonumber(amount) == 1000 then
                aurum_chest = true
                windower.add_to_chat(207, '[MuffinMan] Aurum chest opened!')
            end 

            -- Check if defeated Naakuals
            if tonumber(amount) == 1500 then
                naaks = naaks + 1
                windower.add_to_chat(207, '[MuffinMan] Naakual chest opened!')
            end


        else
        end
    end
end)


-- Command handler
windower.register_event('addon command', function(cmd, ...)
    local args = T{...}
    cmd = cmd and cmd:lower()

    if cmd == 'reset' then
        windower.send_command('scoreboard reset')
        gallimaufry_total = 0
        party_jobs = {}
        windower.add_to_chat(207, '[MuffinMan] Gallimaufry tally and parse have been reset.')
    elseif cmd == 'total' then
        windower.add_to_chat(207, ('[MuffinMan] Current gallimaufry total: %s'):format(comma_value(gallimaufry_total)))
    elseif cmd == 'report' then
        windower.add_to_chat(207, '[MuffinMan] Generating full report...')
        coroutine.schedule(generate_report, 0.5) 
    elseif cmd == 'discord' then
        if not push_to_discord then
            push_to_discord = true
            windower.add_to_chat(207, '[MuffinMan] Enabled report pushes to Discord.')
        else 
            push_to_discord = false
            windower.add_to_chat(207, '[MuffinMan] Disabled report pushes to Discord.')
        end
    else
        windower.add_to_chat(123, '[MuffinMan] Commands:')
        windower.add_to_chat(123, '//mm total     - Show gallimaufry total')
        windower.add_to_chat(123, '//mm reset     - Reset gallimaufry and parse')
        windower.add_to_chat(123, '//mm report    - Save gallimaufry and damage report to file')
        windower.add_to_chat(123, '//mm discord   - Enables/disables automatic push to Discord channel via webhook.')
    end
end)