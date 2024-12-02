local function process(input)
    local left_list, right_map = {}, {}
    for line in input:gmatch("(.-)\n") do
        local _, _, left, right = line:find("(%d+)   (%d+)")
        local l, r = tonumber(left), tonumber(right)
        if not l or not r then error("bad input") end
        left_list[#left_list + 1] = l
        if right_map[r] then
            right_map[r] = right_map[r] + 1
        else
            right_map[r] = 1
        end
    end
    local output = 0
    for _, val in ipairs(left_list) do
        if right_map[val] then
            output = output + val * right_map[val]
        end
    end
    return output
end

local TEST_INPUT = [[3   4
4   3
2   5
1   3
3   9
3   3
]]

local function main()
  local file = io.input("01.txt")
  if not file then error("file open") end
  local input = io.read("a")
  local output = process(input)
  print(output)
end

local test_output = process(TEST_INPUT)
assert(31 == test_output)
main()
