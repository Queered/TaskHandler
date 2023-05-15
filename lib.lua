local TaskHandler = {}
TaskHandler.__index = TaskHandler

function TaskHandler.new(signal, callback, priority)
    local self = setmetatable({}, TaskHandler)
    self._connection = signal:Connect(function(...)
        if self._waiting then
            self._waiting = false
            local success, result = coroutine.resume(self._thread, ...)
            if not success then
                warn("TaskHandler error: " .. tostring(result))
            end
        else
            local success, result = pcall(callback, self, ...)
            if not success then
                warn("TaskHandler error: " .. tostring(result))
            end
        end
    end)
    self._priority = priority or 0
    return self
end

function TaskHandler:Wait(timeout)
    self._waiting = true
    self._thread = coroutine.running()
    if timeout then
        self._timeout = tick() + timeout
    end
    return coroutine.yield()
end

function TaskHandler:Defer(callback, ...)
    local result = self:Wait(self._timeout and (self._timeout - tick()))
    if result then
        return callback(...)
    else
        self:Cancel()
    end
end

function TaskHandler:Cancel()
    if self._thread then
        local success, result = coroutine.resume(self._thread)
        if not success then
            warn("TaskHandler error: " .. tostring(result))
        end
        self._thread = nil
    end
    self._waiting = false
    self._connection:Disconnect()
end

function TaskHandler:addSignal(signal)
    self._connection:Disconnect()
    self._connection = signal:Connect(function(...)
        if self._waiting then
            self._waiting = false
            local success, result = coroutine.resume(self._thread, ...)
            if not success then
                warn("TaskHandler error: " .. tostring(result))
            end
        else
            local success, result = pcall(self._callback, self, ...)
            if not success then
                warn("TaskHandler error: " .. tostring(result))
            end
        end
    end)
end

function TaskHandler:thenDo(callback, priority)
    local priority = priority or 0
    local signal = Instance.new("BindableEvent")
    local task = TaskHandler.new(signal.Event, callback, priority)
    self:addSignal(signal)
    return task
end

return TaskHandler
