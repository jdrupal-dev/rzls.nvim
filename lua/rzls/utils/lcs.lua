local M = {}

---@class rzls.lcs.Edit
---@field kind rzls.lcs.EditKind
---@field text string

---@enum rzls.lcs.EditKind
M.edit_kind = {
    addition = "addition",
    removal = "removal",
    unchanged = "unchanged",
}

--- Computes the Long Common Subequence table.
--- Reference: [https://en.wikipedia.org/wiki/Longest_common_subsequence#Computing_the_length_of_the_LCS]
---@param source string
---@param target string
function M.generate_table(source, target)
    local n = source:len() + 1
    local m = target:len() + 1

    ---@type integer[][]
    local lcs = {}
    for i = 1, n do
        lcs[i] = {}
        for j = 1, m do
            lcs[i][j] = 0
        end
    end

    for i = 1, n do
        for j = 1, m do
            if i == 1 or j == 1 then
                lcs[i][j] = 0
            elseif source:sub(i - 1, i - 1) == target:sub(j - 1, j - 1) then
                lcs[i][j] = 1 + lcs[i - 1][j - 1]
            else
                lcs[i][j] = math.max(lcs[i - 1][j], lcs[i][j - 1])
            end
        end
    end

    return lcs
end

---@generic T
---@param tbl T[]
---@return T[]
local function reverse_table(tbl)
    local ret = {}
    for i = #tbl, 1, -1 do
        table.insert(ret, tbl[i])
    end
    return ret
end

--- Calculates a diff between two strings using LCS
---@param source string
---@param target string
---@return rzls.lcs.Edit[]
function M.diff(source, target)
    local lcs = M.generate_table(source, target)

    local src_idx = source:len() + 1
    local trt_idx = target:len() + 1

    ---@type rzls.lcs.Edit[]
    local edits = {}

    while src_idx ~= 1 or trt_idx ~= 1 do
        if src_idx == 1 then
            table.insert(edits, {
                kind = M.edit_kind.addition,
                text = target:sub(trt_idx - 1, trt_idx - 1),
            })
            trt_idx = trt_idx - 1
        elseif trt_idx == 1 then
            table.insert(edits, {
                kind = M.edit_kind.removal,
                text = source:sub(src_idx - 1, src_idx - 1),
            })
            src_idx = src_idx - 1
        elseif source:sub(src_idx - 1, src_idx - 1) == target:sub(trt_idx - 1, trt_idx - 1) then
            table.insert(edits, {
                kind = M.edit_kind.unchanged,
                text = source:sub(src_idx - 1, src_idx - 1),
            })
            src_idx = src_idx - 1
            trt_idx = trt_idx - 1
        elseif lcs[src_idx - 1][trt_idx] <= lcs[src_idx][trt_idx - 1] then
            table.insert(edits, {
                kind = M.edit_kind.addition,
                text = target:sub(trt_idx - 1, trt_idx - 1),
            })
            trt_idx = trt_idx - 1
        else
            table.insert(edits, {
                kind = M.edit_kind.removal,
                text = source:sub(src_idx - 1, src_idx - 1),
            })
            src_idx = src_idx - 1
        end
    end

    return reverse_table(edits)
end

---@param edits rzls.lcs.Edit[]
---@param line integer
---@param character integer
---@return lsp.TextEdit[]
function M.to_lsp_edits(edits, line, character)
    local function advance_cursor(edit)
        if edit.text == "\n" then
            line = line + 1
            character = 0
        else
            character = character + 1
        end
    end

    ---@type lsp.TextEdit[]
    local lsp_edits = {}
    local i = 1
    while i < #edits do
        -- Skip all unchanged edits and advance cursor
        while i < #edits and edits[i].kind == M.edit_kind.unchanged do
            advance_cursor(edits[i])
            i = i + 1
        end

        -- No more edits to compute
        if i >= #edits then
            break
        end

        local new_text = ""
        local start_line, start_character = line, character

        -- Collect consecutive additions and removals
        while i < #edits and edits[i].kind ~= M.edit_kind.unchanged do
            if edits[i].kind == M.edit_kind.addition then
                new_text = new_text .. edits[i].text
            elseif edits[i].kind == M.edit_kind.removal then
                advance_cursor(edits[i])
            else
                error("unexcepted edit kind " .. edits[i].kind)
            end
            i = i + 1
        end

        ---@type lsp.TextEdit
        local lsp_edit = {
            newText = new_text,
            range = {
                start = {
                    line = start_line,
                    character = start_character,
                },
                ["end"] = {
                    line = line,
                    character = character,
                },
            },
        }

        table.insert(lsp_edits, lsp_edit)
    end

    return lsp_edits
end

return M