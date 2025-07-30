_addon.name = 'MuffinMan'
_addon.author = 'Kunel'
_addon.version = '1.0'
_addon.commands = {'mm'}

require('chat')
packets = require('packets')
res = require('resources')

local gallimaufry_total = 0
local fight_start_time = nil
local fight_end_time = nil
local party_jobs = {}

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

    -- Add party composition to report
    for _, line in ipairs(format_party_composition()) do
        table.insert(report_output, line)
    end
    table.insert(report_output, "-----------------------------")

    -- Add aminon dmg report
    table.insert(report_output, '[Aminon Damage Report]')
    for _, l in ipairs(format_aminon_report(aminon_block)) do table.insert(report_output, l) end
    table.insert(report_output, '-----------------------------')
    table.insert(report_output, '[Weaponskill Averages]')
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

-- Hook Scoreboard's outgoing text so we can capture reports
windower.register_event('outgoing text', function(original, modified, mode)
end)

-- Capture lines printed to chat (Scoreboard outputs reports here)
windower.register_event('incoming text', function(original, modified, mode)
    if scoreboard_capturing then
        table.insert(output_log, original)
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
    else
        windower.add_to_chat(123, '[MuffinMan] Commands:')
        windower.add_to_chat(123, '//mm total     - Show gallimaufry total')
        windower.add_to_chat(123, '//mm reset     - Reset gallimaufry and parse')
        windower.add_to_chat(123, '//mm report    - Save gallimaufry and damage report to file')
    end
end)