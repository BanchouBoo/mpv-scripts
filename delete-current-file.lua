
--[[

    This script deletes the file that is currently playing
    via keyboard shortcut, the file is moved to the recycle bin.

    On Linux the app trash-cli must be installed first.

    Usage:
    Add bindings to input.conf:
    KP0 script-message-to delete_current_file delete-file KP1 "Press 1 to delete file"

    Press KP0 to initiate the delete operation,
    the script will ask to confirm by pressing KP1.
    You may customize the the init and confirm key and the confirm message.
    Confirm key and confirm message are optional.

]]--

key_bindings = {}

function delete_file(path)
    local is_windows = package.config:sub(1,1) == "\\"

    if is_windows then
        local ps_code = [[& {
            Start-Sleep -Seconds 1
            Add-Type -AssemblyName Microsoft.VisualBasic
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('__path__', 'OnlyErrorDialogs', 'SendToRecycleBin')
        }]]

        local escaped_path = string.gsub(path, "'", "''")
        escaped_path = string.gsub(escaped_path, "’", "’’")
        escaped_path = string.gsub(escaped_path, "%%", "%%%%")
        ps_code = string.gsub(ps_code, "__path__", escaped_path)

        mp.command_native({
            name = "subprocess",
            playback_only = false,
            detach = true,
            args = { 'powershell', '-NoProfile', '-Command', ps_code },
        })
    else
        mp.command_native({
            name = "subprocess",
            playback_only = false,
            detach = true,
            args = { 'trash', file_to_delete },
        })
    end
end

function remove_current_file()
    local count = mp.get_property_number("playlist-count")
    local pos   = mp.get_property_number("playlist-pos")
    local new_pos = 0

    if pos == count - 1 then
        new_pos = pos - 1
    else
        new_pos = pos + 1
    end

    if new_pos > -1 then
        mp.set_property_number("playlist-pos", new_pos)
    end

    mp.command("playlist-remove " .. pos)
end

function handle_confirm_key()
    local path = mp.get_property("path")

    if file_to_delete == path then
        remove_current_file()
        delete_file(file_to_delete)
        remove_bindings()
        file_to_delete = ""
    end
end

function cleanup()
    remove_bindings()
    file_to_delete = ""
    mp.commandv("show-text", "")
end

function get_bindings()
    return {
        { confirm_key,  handle_confirm_key },
    }
end

function add_bindings()
    if #key_bindings > 0 then
        return
    end

    local script_name = mp.get_script_name()

    for _, bind in ipairs(get_bindings()) do
        local name = script_name .. "_key_" .. (#key_bindings + 1)
        key_bindings[#key_bindings + 1] = name
        mp.add_forced_key_binding(bind[1], name, bind[2])
    end
end

function remove_bindings()
    if #key_bindings == 0 then
        return
    end

    for _, name in ipairs(key_bindings) do
        mp.remove_key_binding(name)
    end

    key_bindings = {}
end

function client_message(event)
    if event.args[1] == "delete-file" and #event.args == 1 then
        local path = mp.get_property("path")
        remove_current_file()
        delete_file(path)
    elseif event.args[1] == "delete-file" and #event.args == 3 and #key_bindings == 0 then
        confirm_key = event.args[2]
        mp.add_timeout(10, cleanup)
        add_bindings()
        file_to_delete = mp.get_property("path")
        mp.commandv("show-text", event.args[3], "10000")
    end
end

mp.register_event("client-message", client_message)
