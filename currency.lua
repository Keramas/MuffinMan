local currency = {}

-- Required modules
local packets = require('packets')
require('logger')


-- Packets for currency values
local cur1packet = {} -- For packet 0x113
local cur2packet = {} -- For packet 0x118
local curpackettype = 0

-- Currency name to packet field mapping (separated by packet)
local currency_mapping = {
    -- Packet 0x118 fields (Currencies 2 menu)
    [0x118] = {
        ["Gallimaufry"] = "Gallimaufry",
    }
}

-- List of currencies we care about for MuffinMan 
local tracked_currencies = {
    "Gallimaufry"
}

-- Initialize the currency values
local currency_values = {}
for _, curr in ipairs(tracked_currencies) do
    currency_values[curr] = 0
end

-- Function to update currency values from a specific packet
local function update_currency_values_from_packet(packet_id, packet_data)
    if currency_mapping[packet_id] then
        for curr, packet_field in pairs(currency_mapping[packet_id]) do
            local value = packet_data[packet_field]
            if value then
                currency_values[curr] = tonumber(value) or 0
            end
        end
    end
end

-- Register packet handlers
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
    if id == 0x118 then
        cur2packet = packets.parse('incoming', original)
        curpackettype = 2
        update_currency_values_from_packet(0x118, cur2packet)
    end
end)

-- Function to request currency updates
function currency.request_update()
    -- Send packet 0x10F for basic currency info
    local packet = packets.new('outgoing', 0x10F)
    packets.inject(packet)

    -- Send packet 0x115 for Currencies 2 menu
    coroutine.schedule(function()
        local packet = packets.new('outgoing', 0x115)
        packets.inject(packet)
    end, 1)
end

-- Function to get a specific currency value
function currency.get_value(currency_name)
    return currency_values[currency_name] or 0
end

-- Function to get all tracked currency values
function currency.get_all_values()
    return currency_values
end

-- Function to display all currency values
function currency.display_values()

    local gallimaufry = currency_values['Gallimaufry'] or 0
    --log('  Gallimaufry: ' .. tostring(gallimaufry):color(200))

    return gallimaufry

end

-- Function to get the raw packet data for debugging
function currency.get_debug_packet()
    return cur2packet
end

-- Initialize currency values on load
currency.request_update()

return currency 