const getAllocator = @import("../../base.zig").getAllocator;
const bun = @import("root").bun;
const Output = bun.Output;
const std = @import("std");
const Allocator = std.mem.Allocator;
const JSC = bun.JSC;
const MutableString = bun.MutableString;
const native_endian = @import("builtin").target.cpu.arch.endian();
const lshpack = @import("./lshpack.translated.zig");

const JSValue = JSC.JSValue;

const BinaryType = JSC.BinaryType;

const FrameType = enum(u8) {
    HTTP_FRAME_DATA = 0x00,
    HTTP_FRAME_HEADERS = 0x01,
    HTTP_FRAME_PRIORITY = 0x02,
    HTTP_FRAME_RST_STREAM = 0x03,
    HTTP_FRAME_SETTINGS = 0x04,
    HTTP_FRAME_PUSH_PROMISE = 0x05,
    HTTP_FRAME_PING = 0x06,
    HTTP_FRAME_GOAWAY = 0x07,
    HTTP_FRAME_WINDOW_UPDATE = 0x08,
    HTTP_FRAME_CONTINUATION = 0x09,
};

const PingFrameFlags = enum(u8) {
    ACK = 0x1,
};
const DataFrameFlags = enum(u8) {
    END_STREAM = 0x1,
    PADDED = 0x8,
};
const HeadersFrameFlags = enum(u8) {
    END_STREAM = 0x1,
    END_HEADERS = 0x4,
    PADDED = 0x8,
    PRIORITY = 0x20,
};

const ErrorCode = enum(u32) {
    NO_ERROR = 0x0,
    PROTOCOL_ERROR = 0x1,
    INTERNAL_ERROR = 0x2,
    FLOW_CONTROL_ERROR = 0x3,
    SETTINGS_TIMEOUT = 0x4,
    STREAM_CLOSED = 0x5,
    FRAME_SIZE_ERROR = 0x6,
    REFUSED_STREAM = 0x7,
    CANCEL = 0x8,
    COMPRESSION_ERROR = 0x9,
    CONNECT_ERROR = 0xa,
    ENHANCE_YOUR_CALM = 0xb,
    INADEQUATE_SECURITY = 0xc,
    HTTP_1_1_REQUIRED = 0xd,
};

const SettingsType = enum(u16) {
    SETTINGS_HEADER_TABLE_SIZE = 0x1,
    SETTINGS_ENABLE_PUSH = 0x2,
    SETTINGS_MAX_CONCURRENT_STREAMS = 0x3,
    SETTINGS_INITIAL_WINDOW_SIZE = 0x4,
    SETTINGS_MAX_FRAME_SIZE = 0x5,
    SETTINGS_MAX_HEADER_LIST_SIZE = 0x6,
};

const UInt31WithReserved = packed struct(u32) {
    reserved: bool = false,
    uint31: u31 = 0,

    pub fn from(value: u32) UInt31WithReserved {
        return @bitCast(value);
    }

    pub fn toUInt32(value: UInt31WithReserved) u32 {
        return @bitCast(value);
    }

    pub inline fn fromBytes(src: []const u8) UInt31WithReserved {
        var dst: u32 = 0;
        @memcpy(@as(*[4]u8, @ptrCast(&dst)), src);
        if (native_endian != .Big) {
            dst = @byteSwap(dst);
        }
        return @bitCast(dst);
    }

    pub inline fn write(this: UInt31WithReserved, comptime Writer: type, writer: Writer) void {
        var value: u32 = @bitCast(this);
        if (native_endian != .Big) {
            value = @byteSwap(value);
        }

        _ = writer.write(std.mem.asBytes(&value)) catch 0;
    }
};

const StreamPriority = packed struct(u40) {
    streamIdentifier: u32 = 0,
    weight: u8 = 0,

    pub const byteSize: usize = 5;
    pub inline fn write(this: *StreamPriority, comptime Writer: type, writer: Writer) void {
        var swap = this.*;
        if (native_endian != .Big) {
            std.mem.byteSwapAllFields(StreamPriority, &swap);
        }

        _ = writer.write(std.mem.asBytes(&swap)[0..StreamPriority.byteSize]) catch 0;
    }

    pub inline fn from(dst: *StreamPriority, src: []const u8) void {
        @memcpy(@as(*[StreamPriority.byteSize]u8, @ptrCast(dst)), src);
        if (native_endian != .Big) {
            std.mem.byteSwapAllFields(StreamPriority, dst);
        }
    }
};

const FrameHeader = packed struct(u72) {
    length: u24 = 0,
    type: u8 = @intFromEnum(FrameType.HTTP_FRAME_SETTINGS),
    flags: u8 = 0,
    streamIdentifier: u32 = 0,

    pub const byteSize: usize = 9;
    pub inline fn write(this: *FrameHeader, comptime Writer: type, writer: Writer) void {
        var swap = this.*;
        if (native_endian != .Big) {
            std.mem.byteSwapAllFields(FrameHeader, &swap);
        }

        _ = writer.write(std.mem.asBytes(&swap)[0..FrameHeader.byteSize]) catch 0;
    }

    pub inline fn from(dst: *FrameHeader, src: []const u8, offset: usize, comptime end: bool) void {
        @memcpy(@as(*[FrameHeader.byteSize]u8, @ptrCast(dst))[offset .. src.len + offset], src);
        if (comptime end) {
            if (native_endian != .Big) {
                std.mem.byteSwapAllFields(FrameHeader, dst);
            }
        }
    }
};

const SettingsPayloadUnit = packed struct(u48) {
    type: u16,
    value: u32,
    pub const byteSize: usize = 6;
    pub inline fn from(dst: *SettingsPayloadUnit, src: []const u8, offset: usize, comptime end: bool) void {
        @memcpy(@as(*[SettingsPayloadUnit.byteSize]u8, @ptrCast(dst))[offset .. src.len + offset], src);
        if (comptime end) {
            if (native_endian != .Big) {
                std.mem.byteSwapAllFields(SettingsPayloadUnit, dst);
            }
        }
    }
};

const FullSettingsPayload = packed struct(u288) {
    _headerTableSizeType: u16 = @intFromEnum(SettingsType.SETTINGS_HEADER_TABLE_SIZE),
    headerTableSize: u32 = 4096,
    _enablePushType: u16 = @intFromEnum(SettingsType.SETTINGS_ENABLE_PUSH),
    enablePush: u32 = 1,
    _maxConcurrentStreamsType: u16 = @intFromEnum(SettingsType.SETTINGS_MAX_CONCURRENT_STREAMS),
    maxConcurrentStreams: u32 = 100,
    _initialWindowSizeType: u16 = @intFromEnum(SettingsType.SETTINGS_INITIAL_WINDOW_SIZE),
    initialWindowSize: u32 = 65535,
    _maxFrameSizeType: u16 = @intFromEnum(SettingsType.SETTINGS_MAX_FRAME_SIZE),
    maxFrameSize: u32 = 16384,
    _maxHeaderListSizeType: u16 = @intFromEnum(SettingsType.SETTINGS_MAX_HEADER_LIST_SIZE),
    maxHeaderListSize: u32 = 65535,

    pub const byteSize: usize = 36;
    pub fn toJS(this: *FullSettingsPayload, globalObject: *JSC.JSGlobalObject) JSC.JSValue {
        var result = JSValue.createEmptyObject(globalObject, 6);
        result.put(globalObject, JSC.ZigString.static("headerTableSize"), JSC.JSValue.jsNumber(this.headerTableSize));
        result.put(globalObject, JSC.ZigString.static("enablePush"), JSC.JSValue.jsNumber(this.enablePush));
        result.put(globalObject, JSC.ZigString.static("maxConcurrentStreams"), JSC.JSValue.jsNumber(this.maxConcurrentStreams));
        result.put(globalObject, JSC.ZigString.static("initialWindowSize"), JSC.JSValue.jsNumber(this.initialWindowSize));
        result.put(globalObject, JSC.ZigString.static("maxFrameSize"), JSC.JSValue.jsNumber(this.maxFrameSize));
        result.put(globalObject, JSC.ZigString.static("maxHeaderListSize"), JSC.JSValue.jsNumber(this.maxHeaderListSize));

        return result;
    }

    pub fn updateWith(this: *FullSettingsPayload, option: SettingsPayloadUnit) void {
        switch (@as(SettingsType, @enumFromInt(option.type))) {
            .SETTINGS_HEADER_TABLE_SIZE => this.headerTableSize = option.value,
            .SETTINGS_ENABLE_PUSH => this.enablePush = option.value,
            .SETTINGS_MAX_CONCURRENT_STREAMS => this.maxConcurrentStreams = option.value,
            .SETTINGS_INITIAL_WINDOW_SIZE => this.initialWindowSize = option.value,
            .SETTINGS_MAX_FRAME_SIZE => this.maxFrameSize = option.value,
            .SETTINGS_MAX_HEADER_LIST_SIZE => this.maxHeaderListSize = option.value,
        }
    }
    pub fn write(this: *FullSettingsPayload, comptime Writer: type, writer: Writer) void {
        var swap = this.*;

        if (native_endian != .Big) {
            std.mem.byteSwapAllFields(FullSettingsPayload, &swap);
        }
        _ = writer.write(std.mem.asBytes(&swap)[0..FullSettingsPayload.byteSize]) catch 0;
    }
};

const Handlers = struct {
    onError: JSC.JSValue = .zero,
    onWrite: JSC.JSValue = .zero,
    onStreamError: JSC.JSValue = .zero,
    onStreamStart: JSC.JSValue = .zero,
    onStreamHeaders: JSC.JSValue = .zero,
    onStreamEnd: JSC.JSValue = .zero,
    onStreamData: JSC.JSValue = .zero,
    onRemoteSettings: JSC.JSValue = .zero,
    onLocalSettings: JSC.JSValue = .zero,
    onWantTrailers: JSC.JSValue = .zero,
    onPing: JSC.JSValue = .zero,
    onEnd: JSC.JSValue = .zero,
    onGoAway: JSC.JSValue = .zero,
    onFrameError: JSC.JSValue = .zero,

    binary_type: BinaryType = .Buffer,

    vm: *JSC.VirtualMachine,
    globalObject: *JSC.JSGlobalObject,

    pub fn callEventHandler(this: *Handlers, comptime event: @Type(.EnumLiteral), thisValue: JSValue, data: []const JSValue) bool {
        const callback = @field(this, @tagName(event));
        if (callback == .zero) {
            return false;
        }

        const result = callback.callWithThis(this.globalObject, thisValue, data);
        if (result.isAnyError()) {
            this.vm.onUnhandledError(this.globalObject, result);
        }

        return true;
    }

    pub fn callErrorHandler(this: *Handlers, thisValue: JSValue, err: []const JSValue) bool {
        const onError = this.onError;
        if (onError == .zero) {
            if (err.len > 0)
                this.vm.onUnhandledError(this.globalObject, err[0]);

            return false;
        }

        const result = onError.callWithThis(this.globalObject, thisValue, err);
        if (result.isAnyError()) {
            this.vm.onUnhandledError(this.globalObject, result);
        }

        return true;
    }

    pub fn fromJS(globalObject: *JSC.JSGlobalObject, opts: JSC.JSValue, exception: JSC.C.ExceptionRef) ?Handlers {
        var handlers = Handlers{
            .vm = globalObject.bunVM(),
            .globalObject = globalObject,
        };

        if (opts.isEmptyOrUndefinedOrNull() or opts.isBoolean() or !opts.isObject()) {
            exception.* = JSC.toInvalidArguments("Expected \"handlers\" to be an object", .{}, globalObject).asObjectRef();
            return null;
        }

        const pairs = .{
            .{ "onStreamStart", "streamStart" },
            .{ "onStreamHeaders", "streamHeaders" },
            .{ "onStreamEnd", "streamEnd" },
            .{ "onStreamData", "streamData" },
            .{ "onStreamError", "streamError" },
            .{ "onRemoteSettings", "remoteSettings" },
            .{ "onLocalSettings", "localSettings" },
            .{ "onWantTrailers", "wantTrailers" },
            .{ "onPing", "ping" },
            .{ "onEnd", "end" },
            .{ "onError", "error" },
            .{ "onGoAway", "goaway" },
            .{ "onFrameError", "frameError" },
            .{ "onWrite", "write" },
        };

        inline for (pairs) |pair| {
            if (opts.getTruthy(globalObject, pair.@"1")) |callback_value| {
                if (!callback_value.isCell() or !callback_value.isCallable(globalObject.vm())) {
                    exception.* = JSC.toInvalidArguments(comptime std.fmt.comptimePrint("Expected \"{s}\" callback to be a function", .{pair.@"1"}), .{}, globalObject).asObjectRef();
                    return null;
                }

                @field(handlers, pair.@"0") = callback_value;
            }
        }

        if (handlers.onWrite == .zero) {
            exception.* = JSC.toInvalidArguments("Expected at least \"write\" callback", .{}, globalObject).asObjectRef();
            return null;
        }

        if (opts.getTruthy(globalObject, "binaryType")) |binary_type_value| {
            if (!binary_type_value.isString()) {
                exception.* = JSC.toInvalidArguments("Expected \"binaryType\" to be a string", .{}, globalObject).asObjectRef();
                return null;
            }

            handlers.binary_type = BinaryType.fromJSValue(globalObject, binary_type_value) orelse {
                exception.* = JSC.toInvalidArguments("Expected 'binaryType' to be 'arraybuffer', 'uint8array', 'buffer'", .{}, globalObject).asObjectRef();
                return null;
            };
        }

        return handlers;
    }

    pub fn unprotect(this: *Handlers) void {
        this.onError.unprotect();
        this.onGoAway.unprotect();
        this.onWrite.unprotect();
        this.onStreamError.unprotect();
        this.onStreamStart.unprotect();
        this.onStreamHeaders.unprotect();
        this.onStreamEnd.unprotect();
        this.onStreamData.unprotect();
        this.onStreamError.unprotect();
        this.onLocalSettings.unprotect();
        this.onRemoteSettings.unprotect();
        this.onWantTrailers.unprotect();
        this.onPing.unprotect();
        this.onEnd.unprotect();
        this.onFrameError.unprotect();
    }

    pub fn clear(this: *Handlers) void {
        this.onError = .zero;
        this.onWrite = .zero;
        this.onStreamError = .zero;
        this.onStreamStart = .zero;
        this.onStreamHeaders = .zero;
        this.onStreamEnd = .zero;
        this.onStreamData = .zero;
        this.onStreamError = .zero;
        this.onLocalSettings = .zero;
        this.onRemoteSettings = .zero;
        this.onWantTrailers = .zero;
        this.onPing = .zero;
        this.onEnd = .zero;
        this.onGoAway = .zero;
        this.onFrameError = .zero;
    }

    pub fn protect(this: *Handlers) void {
        this.onError.protect();
        this.onWrite.protect();
        this.onStreamError.protect();
        this.onStreamStart.protect();
        this.onStreamHeaders.protect();
        this.onStreamEnd.protect();
        this.onStreamData.protect();
        this.onStreamError.protect();
        this.onLocalSettings.protect();
        this.onRemoteSettings.protect();
        this.onWantTrailers.protect();
        this.onEnd.protect();
        this.onGoAway.protect();
        this.onFrameError.protect();
    }
};

pub const H2FrameParser = struct {
    pub const log = Output.scoped(.H2FrameParser, false);
    pub usingnamespace JSC.Codegen.JSH2FrameParser;
    const MAX_WINDOW_SIZE = 2147483647;
    const MAX_HEADER_TABLE_SIZE = 4294967295;
    const MAX_STREAM_ID = 2147483647;
    const WINDOW_INCREMENT_SIZE = 65536;
    const MAX_HPACK_HEADER_SIZE = 65536;
    const MAX_FRAME_SIZE = 16777215;

    strong_ctx: JSC.Strong = .{},
    allocator: Allocator,
    handlers: Handlers,
    localSettings: FullSettingsPayload = .{},
    // only available after receiving settings or ACK
    remoteSettings: ?FullSettingsPayload = null,
    // current frame being read
    currentFrame: ?FrameHeader = null,
    // remaining bytes to read for the current frame
    remainingLength: i32 = 0,
    // buffer if more data is needed for the current frame
    readBuffer: MutableString,
    // current window size for the connection
    windowSize: u32 = 65535,
    // used window size for the connection
    usedWindowSize: u32 = 0,
    lastStreamID: u32 = 0,
    streams: bun.U32HashMap(Stream),
    const Stream = struct {
        id: u32 = 0,
        state: enum(u8) {
            IDLE = 0,
            RESERVED_LOCAL = 1,
            RESERVED_REMOTE = 2,
            OPEN = 3,
            HALF_CLOSED_LOCAL = 4,
            HALF_CLOSED_REMOTE = 5,
            CLOSED = 6,
        } = .IDLE,
        waitForTrailers: bool = false,
        endAfterHeaders: bool = false,
        isWaitingMoreHeaders: bool = false,
        padding: ?u8 = 0,
        rstCode: u32 = 0,
        sentHeaders: JSC.JSValue = .zero,
        streamDependency: u32 = 0,
        exclusive: bool = false,
        weight: u16 = 36,
        // current window size for the stream
        windowSize: u32 = 65535,
        // used window size for the stream
        usedWindowSize: u32 = 0,

        decoder: lshpack.lshpack_dec = undefined,
        encoder: lshpack.lshpack_enc = undefined,
        signal: ?*JSC.WebCore.AbortSignal = null,

        pub fn init(streamIdentifier: u32, initialWindowSize: u32, headerTableSize: u32) Stream {
            var stream = Stream{
                .id = streamIdentifier,
                .state = .OPEN,
                .windowSize = initialWindowSize,
                .usedWindowSize = 0,
                .weight = 36,
            };

            if (lshpack.lshpack_enc_init(&stream.encoder) != 0) {
                @panic("OOM");
            }
            lshpack.lshpack_dec_init(&stream.decoder);
            lshpack.lshpack_enc_set_max_capacity(&stream.encoder, headerTableSize);
            lshpack.lshpack_dec_set_max_capacity(&stream.decoder, headerTableSize);

            return stream;
        }

        pub fn canReceiveData(this: *Stream) bool {
            return switch (this.state) {
                .IDLE, .RESERVED_LOCAL, .RESERVED_REMOTE, .OPEN, .HALF_CLOSED_LOCAL => false,
                .HALF_CLOSED_REMOTE, .CLOSED => true,
            };
        }

        pub fn canSendData(this: *Stream) bool {
            return switch (this.state) {
                .IDLE, .RESERVED_LOCAL, .RESERVED_REMOTE, .OPEN, .HALF_CLOSED_REMOTE => false,
                .HALF_CLOSED_LOCAL, .CLOSED => true,
            };
        }

        pub fn attachSignal(this: *Stream, signal: *JSC.WebCore.AbortSignal) void {
            _ = signal.ref();
            this.signal = signal.listen(Stream, this, Stream.abortListener);
        }

        pub fn abortListener(this: *Stream, reason: JSValue) void {
            log("abortListener", .{});
            reason.ensureStillAlive();
            _ = this;
            //TODO: send RST_STREAM
        }

        const HeaderValue = struct {
            name: []const u8,
            value: []const u8,
            next: usize,
        };

        pub fn decode(this: *Stream, header_buffer: *[MAX_HPACK_HEADER_SIZE]u8, src_buffer: []const u8) !HeaderValue {
            var xhdr: lshpack.lsxpack_header = .{};

            lshpack.lsxpack_header_prepare_decode(&xhdr, header_buffer.ptr, 0, header_buffer.len);
            var start = @intFromPtr(src_buffer.ptr);
            var src = src_buffer.ptr;
            if (lshpack.lshpack_dec_decode(&this.decoder, &src, @ptrFromInt(start + src_buffer.len), &xhdr) != 0) {
                return error.UnableToDecode;
            }
            const name = lshpack.lsxpack_header_get_name(&xhdr);
            if (name.len == 0) {
                return error.EmptyHeaderName;
            }
            return .{
                .name = name,
                .value = lshpack.lsxpack_header_get_value(&xhdr),
                .next = @intFromPtr(src) - start,
            };
        }

        pub fn encode(this: *Stream, header_buffer: *[MAX_HPACK_HEADER_SIZE]u8, dst_buffer: []const u8, name: []const u8, value: []const u8, never_index: bool) !usize {
            var xhdr: lshpack.lsxpack_header = .{ .indexed_type = if (never_index) 2 else 0 };
            const size = name.len + value.len;
            if (size > MAX_HPACK_HEADER_SIZE) {
                return error.HeaderTooLarge;
            }

            @memcpy(header_buffer[0..name.len], name);
            @memcpy(header_buffer[name.len..size], value);
            lshpack.lsxpack_header_set_offset2(&xhdr, header_buffer.ptr, 0, name.len, name.len, value.len);
            if (never_index) {
                xhdr.indexed_type = 2;
            }

            var start = @intFromPtr(dst_buffer.ptr);
            const ptr = lshpack.lshpack_enc_encode(&this.encoder, dst_buffer.ptr, @ptrFromInt(start + dst_buffer.len), &xhdr);
            const end = @intFromPtr(ptr) - start;
            if (end > 0) {
                return end;
            }
            return error.UnableToEncode;
        }

        pub fn deinit(this: *Stream) void {
            lshpack.lshpack_dec_cleanup(&this.decoder);
            lshpack.lshpack_enc_cleanup(&this.encoder);
            if (this.signal) |signal| {
                this.signal = null;
                signal.detach(this);
            }
            this.sentHeaders.unprotect();
            this.sentHeaders = .zero;
        }
    };

    /// Calculate the new window size for the connection and the stream
    /// https://datatracker.ietf.org/doc/html/rfc7540#section-6.9.1
    fn ajustWindowSize(this: *H2FrameParser, stream: ?*Stream, payloadSize: u32) void {
        this.usedWindowSize += payloadSize;
        if (this.usedWindowSize >= this.windowSize) {
            var increment_size: u32 = WINDOW_INCREMENT_SIZE;
            var new_size = this.windowSize + increment_size;
            if (new_size > MAX_WINDOW_SIZE) {
                new_size = MAX_WINDOW_SIZE;
                increment_size = this.windowSize - MAX_WINDOW_SIZE;
            }
            if (new_size == this.windowSize) {
                this.sendGoAway(0, .FLOW_CONTROL_ERROR, "Window size overflow", this.lastStreamID);
                return;
            }
            this.windowSize = new_size;
            this.sendWindowUpdate(0, UInt31WithReserved.from(increment_size));
        }

        if (stream) |s| {
            s.usedWindowSize += payloadSize;
            if (s.usedWindowSize >= s.windowSize) {
                var increment_size: u32 = WINDOW_INCREMENT_SIZE;
                var new_size = s.windowSize + increment_size;
                if (new_size > MAX_WINDOW_SIZE) {
                    new_size = MAX_WINDOW_SIZE;
                    increment_size = s.windowSize - MAX_WINDOW_SIZE;
                }
                s.windowSize = new_size;
                this.sendWindowUpdate(s.id, UInt31WithReserved.from(increment_size));
            }
        }
    }

    pub fn setSettings(this: *H2FrameParser, settings: FullSettingsPayload) void {
        var buffer: [FrameHeader.byteSize + FullSettingsPayload.byteSize]u8 = undefined;
        @memset(&buffer, 0);
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();
        var settingsHeader: FrameHeader = .{
            .type = @intFromEnum(FrameType.HTTP_FRAME_SETTINGS),
            .flags = 0,
            .streamIdentifier = 0,
            .length = 36,
        };
        settingsHeader.write(@TypeOf(writer), writer);
        this.localSettings = settings;
        this.localSettings.write(@TypeOf(writer), writer);
        this.write(&buffer);
        this.ajustWindowSize(null, @intCast(buffer.len));
    }

    pub fn endStream(this: *H2FrameParser, stream: *Stream, rstCode: ErrorCode) void {
        var buffer: [FrameHeader.byteSize + 4]u8 = undefined;
        @memset(&buffer, 0);
        var writerStream = std.io.fixedBufferStream(&buffer);
        const writer = writerStream.writer();

        var frame: FrameHeader = .{
            .type = @intFromEnum(FrameType.HTTP_FRAME_RST_STREAM),
            .flags = 0,
            .streamIdentifier = stream.id,
            .length = 4,
        };
        frame.write(@TypeOf(writer), writer);
        var value: u32 = @intFromEnum(rstCode);
        stream.rstCode = value;
        if (native_endian != .Big) {
            value = @byteSwap(value);
        }
        _ = writer.write(std.mem.asBytes(&value)) catch 0;

        stream.state = .CLOSED;
        if (rstCode == .NO_ERROR) {
            this.dispatchWithExtra(.onStreamEnd, JSC.JSValue.jsNumber(stream.id), JSC.JSValue.jsUndefined());
        } else {
            this.dispatchWithExtra(.onStreamError, JSC.JSValue.jsNumber(stream.id), JSC.JSValue.jsNumber(value));
        }

        this.write(&buffer);
    }

    pub fn sendGoAway(this: *H2FrameParser, streamIdentifier: u32, rstCode: ErrorCode, debug_data: []const u8, lastStreamID: u32) void {
        var buffer: [FrameHeader.byteSize + 8]u8 = undefined;
        @memset(&buffer, 0);
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();

        var frame: FrameHeader = .{
            .type = @intFromEnum(FrameType.HTTP_FRAME_GOAWAY),
            .flags = 0,
            .streamIdentifier = streamIdentifier,
            .length = @intCast(8 + debug_data.len),
        };
        frame.write(@TypeOf(writer), writer);
        var last_id = UInt31WithReserved.from(lastStreamID);
        last_id.write(@TypeOf(writer), writer);
        var value: u32 = @intFromEnum(rstCode);
        if (native_endian != .Big) {
            value = @byteSwap(value);
        }
        _ = writer.write(std.mem.asBytes(&value)) catch 0;

        this.write(&buffer);
        if (debug_data.len > 0) {
            this.write(debug_data);
        }
        const chunk = this.handlers.binary_type.toJS(debug_data, this.handlers.globalObject);
        if (rstCode != .NO_ERROR) {
            this.dispatchWith2Extra(.onError, JSC.JSValue.jsNumber(value), JSC.JSValue.jsNumber(this.lastStreamID), chunk);
        }
        this.dispatchWithExtra(.onEnd, JSC.JSValue.jsNumber(this.lastStreamID), chunk);
    }

    pub fn sendPing(this: *H2FrameParser, ack: bool, payload: []const u8) void {
        var buffer: [FrameHeader.byteSize + 8]u8 = undefined;
        @memset(&buffer, 0);
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();
        var frame = FrameHeader{
            .type = @intFromEnum(FrameType.HTTP_FRAME_PING),
            .flags = if (ack) @intFromEnum(PingFrameFlags.ACK) else 0,
            .streamIdentifier = 0,
            .length = 8,
        };
        frame.write(@TypeOf(writer), writer);
        _ = writer.write(payload) catch 0;
        this.write(&buffer);
    }

    pub fn sendPrefaceAndSettings(this: *H2FrameParser) void {
        // PREFACE + Settings Frame
        var preface_buffer: [24 + FrameHeader.byteSize + FullSettingsPayload.byteSize]u8 = undefined;
        @memset(&preface_buffer, 0);
        var preface_stream = std.io.fixedBufferStream(&preface_buffer);
        const writer = preface_stream.writer();
        _ = writer.write("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n") catch 0;
        var settingsHeader: FrameHeader = .{
            .type = @intFromEnum(FrameType.HTTP_FRAME_SETTINGS),
            .flags = 0,
            .streamIdentifier = 0,
            .length = 36,
        };
        settingsHeader.write(@TypeOf(writer), writer);
        this.localSettings.write(@TypeOf(writer), writer);
        this.write(&preface_buffer);
        this.ajustWindowSize(null, @intCast(preface_buffer.len));
    }

    pub fn sendWindowUpdate(this: *H2FrameParser, streamIdentifier: u32, windowSize: UInt31WithReserved) void {
        var buffer: [FrameHeader.byteSize + 4]u8 = undefined;
        @memset(&buffer, 0);
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();
        var settingsHeader: FrameHeader = .{
            .type = @intFromEnum(FrameType.HTTP_FRAME_WINDOW_UPDATE),
            .flags = 0,
            .streamIdentifier = streamIdentifier,
            .length = 4,
        };
        settingsHeader.write(@TypeOf(writer), writer);
        // always clear reserved bit
        const cleanWindowSize: UInt31WithReserved = .{
            .reserved = false,
            .uint31 = windowSize.uint31,
        };
        cleanWindowSize.write(@TypeOf(writer), writer);
        this.write(&buffer);
    }

    pub fn dispatch(this: *H2FrameParser, comptime event: @Type(.EnumLiteral), value: JSC.JSValue) void {
        JSC.markBinding(@src());
        const ctx_value = this.strong_ctx.get() orelse JSC.JSValue.jsUndefined();
        value.ensureStillAlive();
        _ = this.handlers.callEventHandler(event, ctx_value, &[_]JSC.JSValue{ ctx_value, value });
    }

    pub fn dispatchWithExtra(this: *H2FrameParser, comptime event: @Type(.EnumLiteral), value: JSC.JSValue, extra: JSC.JSValue) void {
        JSC.markBinding(@src());
        const ctx_value = this.strong_ctx.get() orelse JSC.JSValue.jsUndefined();
        value.ensureStillAlive();
        _ = this.handlers.callEventHandler(event, ctx_value, &[_]JSC.JSValue{ ctx_value, value, extra });
    }

    pub fn dispatchWith2Extra(this: *H2FrameParser, comptime event: @Type(.EnumLiteral), value: JSC.JSValue, extra: JSC.JSValue, extra2: JSC.JSValue) void {
        JSC.markBinding(@src());
        const ctx_value = this.strong_ctx.get() orelse JSC.JSValue.jsUndefined();
        value.ensureStillAlive();
        _ = this.handlers.callEventHandler(event, ctx_value, &[_]JSC.JSValue{ ctx_value, value, extra, extra2 });
    }

    pub fn write(this: *H2FrameParser, bytes: []const u8) void {
        JSC.markBinding(@src());
        log("write", .{});

        const output_value = this.handlers.binary_type.toJS(bytes, this.handlers.globalObject);
        this.dispatch(.onWrite, output_value);
    }

    pub fn detach(this: *H2FrameParser, _: *JSC.JSGlobalObject, _: *JSC.CallFrame) callconv(.C) JSValue {
        JSC.markBinding(@src());
        log("detach", .{});
        var handler = this.handlers;
        defer handler.unprotect();
        this.handlers.clear();

        return JSC.JSValue.jsUndefined();
    }

    const Payload = struct {
        data: []const u8,
        end: usize,
    };

    // Default handling for payload is buffering it
    // for data frames we use another strategy
    pub fn handleIncommingPayload(this: *H2FrameParser, data: []const u8, streamIdentifier: u32) ?Payload {
        const end: usize = @min(@as(usize, @intCast(this.remainingLength)), data.len);
        const payload = data[0..end];
        this.remainingLength -= @intCast(end);
        if (this.remainingLength > 0) {
            // buffer more data
            _ = this.readBuffer.appendSlice(payload) catch @panic("OOM");
            return null;
        } else if (this.remainingLength < 0) {
            this.sendGoAway(streamIdentifier, ErrorCode.FRAME_SIZE_ERROR, "Invalid frame size", this.lastStreamID);
            return null;
        }

        this.currentFrame = null;
        return .{
            .data = payload,
            .end = end,
        };
    }

    pub fn handleWindowUpdateFrame(this: *H2FrameParser, frame: FrameHeader, data: []const u8, stream: ?*Stream) usize {
        // must be always 4 bytes (https://datatracker.ietf.org/doc/html/rfc7540#section-6.9)
        if (frame.length != 4) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.FRAME_SIZE_ERROR, "Invalid dataframe frame size", this.lastStreamID);
            return data.len;
        }

        if (handleIncommingPayload(this, data, frame.streamIdentifier)) |content| {
            const payload = content.data;
            const windowSizeIncrement = UInt31WithReserved.fromBytes(payload);
            this.readBuffer.reset();
            // we automatically send a window update when receiving one
            this.sendWindowUpdate(frame.streamIdentifier, windowSizeIncrement);
            if (stream) |s| {
                s.windowSize += windowSizeIncrement.uint31;
            } else {
                this.windowSize += windowSizeIncrement.uint31;
            }
            log("windowSizeIncrement stream {} value {}", .{ frame.streamIdentifier, windowSizeIncrement.uint31 });
            return content.end;
        }
        // needs more data
        return data.len;
    }

    pub fn decodeHeaderBlock(this: *H2FrameParser, payload: []const u8, stream: *Stream, flags: u8) void {
        log("decodeHeaderBlock", .{});

        var header_buffer: [MAX_HPACK_HEADER_SIZE]u8 = undefined;
        var offset: usize = 0;

        const globalObject = this.handlers.globalObject;

        const headers = JSC.JSValue.createEmptyArray(globalObject, 0);

        while (true) {
            const header = stream.decode(&header_buffer, payload[offset..]) catch break;
            offset += header.next;
            var result = JSValue.createEmptyObject(globalObject, 2);
            const name = JSC.ZigString.fromUTF8(header.name).toValueGC(globalObject);
            const value = JSC.ZigString.fromUTF8(header.value).toValueGC(globalObject);
            result.put(globalObject, JSC.ZigString.static("name"), name);
            result.put(globalObject, JSC.ZigString.static("value"), value);
            headers.push(globalObject, result);
            if (offset >= payload.len) {
                break;
            }
        }

        this.dispatchWith2Extra(.onStreamHeaders, JSC.JSValue.jsNumber(stream.id), headers, JSC.JSValue.jsNumber(flags));
    }

    pub fn handleDataFrame(this: *H2FrameParser, frame: FrameHeader, data: []const u8, stream_: ?*Stream) usize {
        if (stream_ == null) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Data frame on connection stream", this.lastStreamID);
            return data.len;
        }
        var settings = this.remoteSettings orelse this.localSettings;

        if (frame.length > settings.maxFrameSize) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.FRAME_SIZE_ERROR, "Invalid dataframe frame size", this.lastStreamID);
            return data.len;
        }

        var stream = stream_.?;
        this.readBuffer.reset();

        const end: usize = @min(@as(usize, @intCast(this.remainingLength)), data.len);
        var payload = data[0..end];

        var data_needed: isize = this.remainingLength;

        this.remainingLength -= @intCast(end);
        var padding: u8 = 0;
        if (frame.flags & @intFromEnum(DataFrameFlags.PADDED) != 0) {
            if (stream.padding) |p| {
                padding = p;
            } else {
                if (payload.len == 0) {
                    // await more data because we need to know the padding length
                    return data.len;
                }
                padding = payload[0];
                stream.padding = payload[0];
                payload = payload[1..];
            }
        }

        if (this.remainingLength < 0) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.FRAME_SIZE_ERROR, "Invalid data frame size", this.lastStreamID);
            return data.len;
        }

        // ignore padding
        if (data_needed > padding) {
            data_needed -= padding;
            payload = payload[0..@min(@as(usize, @intCast(data_needed)), payload.len)];
            const chunk = this.handlers.binary_type.toJS(payload, this.handlers.globalObject);
            this.dispatchWithExtra(.onStreamData, JSC.JSValue.jsNumber(frame.streamIdentifier), chunk);
        } else {
            data_needed = 0;
        }

        if (this.remainingLength == 0) {
            this.currentFrame = null;
            if (frame.flags & @intFromEnum(DataFrameFlags.END_STREAM) != 0) {
                stream.state = .HALF_CLOSED_REMOTE;
                this.dispatch(.onStreamEnd, JSC.JSValue.jsNumber(frame.streamIdentifier));
            }
        }

        return end;
    }
    pub fn handleGoAwayFrame(this: *H2FrameParser, frame: FrameHeader, data: []const u8, stream_: ?*Stream) usize {
        if (stream_ != null) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "GoAway frame on stream", this.lastStreamID);
            return data.len;
        }
        var settings = this.remoteSettings orelse this.localSettings;

        if (frame.length < 8 or frame.length > settings.maxFrameSize) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.FRAME_SIZE_ERROR, "invalid GoAway frame size", this.lastStreamID);
            return data.len;
        }

        if (handleIncommingPayload(this, data, frame.streamIdentifier)) |content| {
            const payload = content.data;
            const last_stream_id: u32 = @intCast(UInt31WithReserved.fromBytes(payload[0..4]).uint31);
            const error_code = UInt31WithReserved.fromBytes(payload[4..8]).toUInt32();
            const chunk = this.handlers.binary_type.toJS(payload[8..], this.handlers.globalObject);
            if (error_code != @intFromEnum(ErrorCode.NO_ERROR)) {
                this.dispatchWith2Extra(.onGoAway, JSC.JSValue.jsNumber(error_code), JSC.JSValue.jsNumber(last_stream_id), chunk);
            } else {
                this.dispatchWithExtra(.onGoAway, JSC.JSValue.jsNumber(last_stream_id), chunk);
            }
            this.readBuffer.reset();
            return content.end;
        }
        return data.len;
    }
    pub fn handleRSTStreamFrame(this: *H2FrameParser, frame: FrameHeader, data: []const u8, stream_: ?*Stream) usize {
        if (stream_ == null) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "RST_STREAM frame on connection stream", this.lastStreamID);
            return data.len;
        }
        if (frame.length != 4) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.FRAME_SIZE_ERROR, "invalid RST_STREAM frame size", this.lastStreamID);
            return data.len;
        }

        var stream = stream_.?;

        if (stream.isWaitingMoreHeaders) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Headers frame without continuation", this.lastStreamID);
            return data.len;
        }

        if (handleIncommingPayload(this, data, frame.streamIdentifier)) |content| {
            const payload = content.data;
            const rst_code = UInt31WithReserved.fromBytes(payload).toUInt32();
            stream.rstCode = rst_code;
            this.readBuffer.reset();
            if (rst_code != @intFromEnum(ErrorCode.NO_ERROR)) {
                this.dispatchWithExtra(.onStreamError, JSC.JSValue.jsNumber(stream.id), JSC.JSValue.jsNumber(rst_code));
            }
            this.endStream(stream, ErrorCode.NO_ERROR);

            return content.end;
        }
        return data.len;
    }
    pub fn handlePingFrame(this: *H2FrameParser, frame: FrameHeader, data: []const u8, stream_: ?*Stream) usize {
        if (stream_ != null) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Ping frame on stream", this.lastStreamID);
            return data.len;
        }

        if (frame.length != 8) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.FRAME_SIZE_ERROR, "Invalid ping frame size", this.lastStreamID);
            return data.len;
        }

        if (handleIncommingPayload(this, data, frame.streamIdentifier)) |content| {
            const payload = content.data;
            this.dispatch(.onPing, this.handlers.binary_type.toJS(payload, this.handlers.globalObject));
            // if is not ACK send response
            if (frame.flags & @intFromEnum(PingFrameFlags.ACK) == 0) {
                this.sendPing(true, payload);
            }
            this.readBuffer.reset();
            return content.end;
        }
        return data.len;
    }
    pub fn handlePriorityFrame(this: *H2FrameParser, frame: FrameHeader, data: []const u8, stream_: ?*Stream) usize {
        if (stream_ == null) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Priority frame on connection stream", this.lastStreamID);
            return data.len;
        }

        if (frame.length != StreamPriority.byteSize) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.FRAME_SIZE_ERROR, "invalid Priority frame size", this.lastStreamID);
            return data.len;
        }

        var stream = stream_.?;

        if (handleIncommingPayload(this, data, frame.streamIdentifier)) |content| {
            const payload = content.data;

            var priority: StreamPriority = undefined;
            priority.from(payload);

            const stream_identifier = UInt31WithReserved.from(priority.streamIdentifier);
            stream.streamDependency = stream_identifier.uint31;
            stream.exclusive = stream_identifier.reserved;
            stream.weight = priority.weight;

            this.readBuffer.reset();
            return content.end;
        }
        return data.len;
    }
    pub fn handleContinuationFrame(this: *H2FrameParser, frame: FrameHeader, data: []const u8, stream_: ?*Stream) usize {
        if (stream_ == null) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Continuation on connection stream", this.lastStreamID);
            return data.len;
        }
        var stream = stream_.?;
        if (!stream.isWaitingMoreHeaders) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Continuation without headers", this.lastStreamID);
            return data.len;
        }
        if (handleIncommingPayload(this, data, frame.streamIdentifier)) |content| {
            const payload = content.data;
            this.decodeHeaderBlock(payload[0..payload.len], stream, frame.flags);
            this.readBuffer.reset();
            if (frame.flags & @intFromEnum(HeadersFrameFlags.END_HEADERS) != 0) {
                if (stream.state == .HALF_CLOSED_REMOTE) {
                    // no more continuation headers we can call it closed
                    stream.state = .CLOSED;
                    this.dispatch(.onStreamEnd, JSC.JSValue.jsNumber(frame.streamIdentifier));
                }
                stream.isWaitingMoreHeaders = false;
            }

            this.readBuffer.reset();
            return content.end;
        }

        // needs more data
        return data.len;
    }

    pub fn handleHeadersFrame(this: *H2FrameParser, frame: FrameHeader, data: []const u8, stream_: ?*Stream) usize {
        if (stream_ == null) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Headers frame on connection stream", this.lastStreamID);
            return data.len;
        }
        var settings = this.remoteSettings orelse this.localSettings;
        if (frame.length > settings.maxFrameSize) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.FRAME_SIZE_ERROR, "invalid Headers frame size", this.lastStreamID);
            return data.len;
        }
        var stream = stream_.?;

        if (stream.isWaitingMoreHeaders) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Headers frame without continuation", this.lastStreamID);
            return data.len;
        }

        if (handleIncommingPayload(this, data, frame.streamIdentifier)) |content| {
            const payload = content.data;
            var offset: usize = 0;
            var padding: usize = 0;
            if (frame.flags & @intFromEnum(HeadersFrameFlags.PADDED) != 0) {
                // padding length
                padding = payload[0];
                offset += 1;
            }
            if (frame.flags & @intFromEnum(HeadersFrameFlags.PRIORITY) != 0) {
                // skip priority (client dont need to care about it)
                offset += 5;
            }
            this.decodeHeaderBlock(payload[offset .. payload.len - padding], stream, frame.flags);
            stream.isWaitingMoreHeaders = frame.flags & @intFromEnum(HeadersFrameFlags.END_HEADERS) != 0;
            if (frame.flags & @intFromEnum(HeadersFrameFlags.END_STREAM) != 0) {
                if (stream.isWaitingMoreHeaders) {
                    stream.state = .HALF_CLOSED_REMOTE;
                } else {
                    // no more continuation headers we can call it closed
                    stream.state = .CLOSED;
                    this.dispatch(.onStreamEnd, JSC.JSValue.jsNumber(frame.streamIdentifier));
                }
            }
            this.readBuffer.reset();
            return content.end;
        }

        // needs more data
        return data.len;
    }
    pub fn handleSettingsFrame(this: *H2FrameParser, frame: FrameHeader, data: []const u8) usize {
        if (frame.streamIdentifier != 0) {
            this.sendGoAway(frame.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Settings frame on connection stream", this.lastStreamID);
            return data.len;
        }

        const settingByteSize = SettingsPayloadUnit.byteSize;
        if (frame.length > 0) {
            if (frame.flags & 0x1 != 0 or frame.length % settingByteSize != 0) {
                this.sendGoAway(frame.streamIdentifier, ErrorCode.FRAME_SIZE_ERROR, "Invalid settings frame size", this.lastStreamID);
                return data.len;
            }
        } else {
            if (frame.flags & 0x1 != 0) {
                // we received an ACK
                this.remoteSettings = this.localSettings;
                this.dispatch(.onLocalSettings, this.localSettings.toJS(this.handlers.globalObject));
            }
            this.currentFrame = null;
            return 0;
        }

        if (handleIncommingPayload(this, data, frame.streamIdentifier)) |content| {
            var remoteSettings = this.remoteSettings orelse this.localSettings;
            var i: usize = 0;
            const payload = content.data;
            while (i < payload.len) {
                defer i += settingByteSize;
                var unit: SettingsPayloadUnit = undefined;
                SettingsPayloadUnit.from(&unit, payload[i .. i + settingByteSize], 0, true);
                remoteSettings.updateWith(unit);
            }
            this.readBuffer.reset();
            this.remoteSettings = remoteSettings;
            this.dispatch(.onRemoteSettings, remoteSettings.toJS(this.handlers.globalObject));
            return content.end;
        }
        // needs more data
        return data.len;
    }

    fn handleReceivedStreamID(this: *H2FrameParser, streamIdentifier: u32) ?*Stream {
        // connection stream
        if (streamIdentifier == 0) {
            return null;
        }

        // already exists
        if (this.streams.getEntry(streamIdentifier)) |entry| {
            return entry.value_ptr;
        }

        if (streamIdentifier > this.lastStreamID) {
            this.lastStreamID = streamIdentifier;
        }

        // new stream open
        const settings = this.remoteSettings orelse this.localSettings;
        var entry = this.streams.getOrPut(streamIdentifier) catch @panic("OOM");
        entry.value_ptr.* = Stream.init(streamIdentifier, settings.initialWindowSize, settings.headerTableSize);

        this.dispatch(.onStreamStart, JSC.JSValue.jsNumber(streamIdentifier));
        return entry.value_ptr;
    }

    pub fn readBytes(this: *H2FrameParser, bytes: []u8) usize {
        log("read", .{});
        if (this.currentFrame) |header| {
            log("current frame {} {} {} {}", .{ header.type, header.length, header.flags, header.streamIdentifier });

            const stream = this.handleReceivedStreamID(header.streamIdentifier);
            return switch (@as(FrameType, @enumFromInt(header.type))) {
                FrameType.HTTP_FRAME_SETTINGS => this.handleSettingsFrame(header, bytes),
                FrameType.HTTP_FRAME_WINDOW_UPDATE => this.handleWindowUpdateFrame(header, bytes, stream),
                FrameType.HTTP_FRAME_HEADERS => this.handleHeadersFrame(header, bytes, stream),
                FrameType.HTTP_FRAME_DATA => this.handleDataFrame(header, bytes, stream),
                FrameType.HTTP_FRAME_CONTINUATION => this.handleContinuationFrame(header, bytes, stream),
                FrameType.HTTP_FRAME_PRIORITY => this.handlePriorityFrame(header, bytes, stream),
                FrameType.HTTP_FRAME_PING => this.handlePingFrame(header, bytes, stream),
                FrameType.HTTP_FRAME_GOAWAY => this.handleGoAwayFrame(header, bytes, stream),
                FrameType.HTTP_FRAME_RST_STREAM => this.handleRSTStreamFrame(header, bytes, stream),
                else => {
                    this.sendGoAway(header.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Unknown frame type", this.lastStreamID);
                    return bytes.len;
                },
            };
        }

        // nothing to do
        if (bytes.len == 0) return bytes.len;

        const buffered_data = this.readBuffer.list.items.len;

        var header: FrameHeader = undefined;
        // we can have less than 9 bytes buffered
        if (buffered_data > 0) {
            const total = buffered_data + bytes.len;
            if (total < FrameHeader.byteSize) {
                // buffer more data
                _ = this.readBuffer.appendSlice(bytes) catch @panic("OOM");
                return bytes.len;
            }
            FrameHeader.from(&header, this.readBuffer.list.items[0..buffered_data], 0, false);
            const needed = FrameHeader.byteSize - buffered_data;
            FrameHeader.from(&header, bytes[0..needed], buffered_data, true);
            // ignore the reserved bit
            const id = UInt31WithReserved.from(header.streamIdentifier);
            header.streamIdentifier = @intCast(id.uint31);
            // reset for later use
            this.readBuffer.reset();

            this.currentFrame = header;
            this.remainingLength = header.length;
            log("new frame {} {} {} {}", .{ header.type, header.length, header.flags, header.streamIdentifier });
            const stream = this.handleReceivedStreamID(header.streamIdentifier);
            this.ajustWindowSize(stream, header.length);
            return switch (@as(FrameType, @enumFromInt(header.type))) {
                FrameType.HTTP_FRAME_SETTINGS => this.handleSettingsFrame(header, bytes[needed..]) + needed,
                FrameType.HTTP_FRAME_WINDOW_UPDATE => this.handleWindowUpdateFrame(header, bytes[needed..], stream) + needed,
                FrameType.HTTP_FRAME_HEADERS => this.handleHeadersFrame(header, bytes[needed..], stream) + needed,
                FrameType.HTTP_FRAME_DATA => this.handleDataFrame(header, bytes[needed..], stream) + needed,
                FrameType.HTTP_FRAME_CONTINUATION => this.handleContinuationFrame(header, bytes[needed..], stream) + needed,
                FrameType.HTTP_FRAME_PRIORITY => this.handlePriorityFrame(header, bytes[needed..], stream) + needed,
                FrameType.HTTP_FRAME_PING => this.handlePingFrame(header, bytes[needed..], stream) + needed,
                FrameType.HTTP_FRAME_GOAWAY => this.handleGoAwayFrame(header, bytes[needed..], stream) + needed,
                FrameType.HTTP_FRAME_RST_STREAM => this.handleRSTStreamFrame(header, bytes[needed..], stream) + needed,
                else => {
                    this.sendGoAway(header.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Unknown frame type", this.lastStreamID);
                    return bytes.len;
                },
            };
        }

        if (bytes.len < FrameHeader.byteSize) {
            // buffer more dheaderata
            this.readBuffer.appendSlice(bytes) catch @panic("OOM");
            return bytes.len;
        }

        FrameHeader.from(&header, bytes[0..FrameHeader.byteSize], 0, true);

        log("new frame {} {} {} {}", .{ header.type, header.length, header.flags, header.streamIdentifier });
        this.currentFrame = header;
        this.remainingLength = header.length;
        const stream = this.handleReceivedStreamID(header.streamIdentifier);
        this.ajustWindowSize(stream, header.length);
        return switch (@as(FrameType, @enumFromInt(header.type))) {
            FrameType.HTTP_FRAME_SETTINGS => this.handleSettingsFrame(header, bytes[FrameHeader.byteSize..]) + FrameHeader.byteSize,
            FrameType.HTTP_FRAME_WINDOW_UPDATE => this.handleWindowUpdateFrame(header, bytes[FrameHeader.byteSize..], stream) + FrameHeader.byteSize,
            FrameType.HTTP_FRAME_HEADERS => this.handleHeadersFrame(header, bytes[FrameHeader.byteSize..], stream) + FrameHeader.byteSize,
            FrameType.HTTP_FRAME_DATA => this.handleDataFrame(header, bytes[FrameHeader.byteSize..], stream) + FrameHeader.byteSize,
            FrameType.HTTP_FRAME_CONTINUATION => this.handleContinuationFrame(header, bytes[FrameHeader.byteSize..], stream) + FrameHeader.byteSize,
            FrameType.HTTP_FRAME_PRIORITY => this.handlePriorityFrame(header, bytes[FrameHeader.byteSize..], stream) + FrameHeader.byteSize,
            FrameType.HTTP_FRAME_PING => this.handlePingFrame(header, bytes[FrameHeader.byteSize..], stream) + FrameHeader.byteSize,
            FrameType.HTTP_FRAME_GOAWAY => this.handleGoAwayFrame(header, bytes[FrameHeader.byteSize..], stream) + FrameHeader.byteSize,
            FrameType.HTTP_FRAME_RST_STREAM => this.handleRSTStreamFrame(header, bytes[FrameHeader.byteSize..], stream) + FrameHeader.byteSize,
            else => {
                this.sendGoAway(header.streamIdentifier, ErrorCode.PROTOCOL_ERROR, "Unknown frame type", this.lastStreamID);
                return bytes.len;
            },
        };
    }

    const DirectWriterStruct = struct {
        writer: *H2FrameParser,
        pub fn write(this: *const DirectWriterStruct, data: []const u8) !bool {
            this.writer.write(data);
            return true;
        }
    };

    fn toWriter(this: *H2FrameParser) DirectWriterStruct {
        return DirectWriterStruct{ .writer = this };
    }
    pub fn setEncoding(this: *H2FrameParser, globalObject: *JSC.JSGlobalObject, callframe: *JSC.CallFrame) callconv(.C) JSValue {
        JSC.markBinding(@src());
        const args_list = callframe.arguments(1);
        if (args_list.len < 1) {
            globalObject.throw("Expected encoding argument", .{});
            return .zero;
        }
        this.handlers.binary_type = BinaryType.fromJSValue(globalObject, args_list.ptr[0]) orelse {
            const err = JSC.toInvalidArguments("Expected 'binaryType' to be 'arraybuffer', 'uint8array', 'buffer'", .{}, globalObject).asObjectRef();
            globalObject.throwValue(err);
            return .zero;
        };

        return JSC.JSValue.jsUndefined();
    }

    pub fn loadSettingsFromJSValue(this: *H2FrameParser, globalObject: *JSC.JSGlobalObject, options: JSC.JSValue) bool {

        if(options.isEmptyOrUndefinedOrNull() or !options.isObject()) {
            globalObject.throw("Expected settings to be a object", .{});
            return false;
        }

        if(options.get(globalObject, "headerTableSize")) |headerTableSize| {
            if(headerTableSize.isNumber()) {
              const headerTableSizeValue =  headerTableSize.toInt32();
              if(headerTableSizeValue > MAX_HEADER_TABLE_SIZE or headerTableSizeValue < 0) {
                globalObject.throw("Expected headerTableSize to be a number between 0 and 2^32-1", .{});
                return false;
              } 
              this.localSettings.headerTableSize = @intCast(headerTableSizeValue);
            } else if(!headerTableSize.isEmptyOrUndefinedOrNull()) {
                globalObject.throw("Expected headerTableSize to be a number", .{});
                return false;
            }
        }

        if(options.get(globalObject, "enablePush")) |enablePush| {
            if(enablePush.isBoolean()) {
              this.localSettings.enablePush = if(enablePush.asBoolean()) 1 else 0;
            } else if(!enablePush.isEmptyOrUndefinedOrNull()) {
                globalObject.throw("Expected enablePush to be a boolean", .{});
                return false;
            }
        }
        
        if(options.get(globalObject, "initialWindowSize")) |initialWindowSize| {
            if(initialWindowSize.isNumber()) {
              const initialWindowSizeValue = initialWindowSize.toInt32();
               if(initialWindowSizeValue > MAX_HEADER_TABLE_SIZE or initialWindowSizeValue < 0) {
                globalObject.throw("Expected initialWindowSize to be a number between 0 and 2^32-1", .{});
                return false;
              } 
            } else if(!initialWindowSize.isEmptyOrUndefinedOrNull()) {
                globalObject.throw("Expected initialWindowSize to be a number", .{});
                return false;
            }
        }

        if(options.get(globalObject, "maxFrameSize")) |maxFrameSize| {
            if(maxFrameSize.isNumber()) {
              const maxFrameSizeValue = maxFrameSize.toInt32();
              if(maxFrameSizeValue > MAX_FRAME_SIZE or maxFrameSizeValue < 16384) {
                globalObject.throw("Expected maxFrameSize to be a number between 16,384 and 2^24-1", .{});
                return false;
              } 
              this.localSettings.maxFrameSize = @intCast(maxFrameSizeValue);
            } else if(!maxFrameSize.isEmptyOrUndefinedOrNull()) {
                globalObject.throw("Expected maxFrameSize to be a number", .{});
                return false;
            }
        }

        if(options.get(globalObject, "maxConcurrentStreams")) |maxConcurrentStreams| {
            if(maxConcurrentStreams.isNumber()) {
              const maxConcurrentStreamsValue = maxConcurrentStreams.toInt32();
              if(maxConcurrentStreamsValue > MAX_HEADER_TABLE_SIZE or maxConcurrentStreamsValue < 0) {
                globalObject.throw("Expected maxConcurrentStreams to be a number between 0 and 2^32-1", .{});
                return false;
              } 
              this.localSettings.maxConcurrentStreams = @intCast(maxConcurrentStreamsValue);
            } else if(!maxConcurrentStreams.isEmptyOrUndefinedOrNull()) {
                globalObject.throw("Expected maxConcurrentStreams to be a number", .{});
                return false;
            }
        }
        
        if(options.get(globalObject, "maxHeaderListSize")) |maxHeaderListSize| {
            if(maxHeaderListSize.isNumber()) {
              const maxHeaderListSizeValue = maxHeaderListSize.toInt32();
              if(maxHeaderListSizeValue > MAX_HEADER_TABLE_SIZE or maxHeaderListSizeValue < 0) {
                globalObject.throw("Expected maxHeaderListSize to be a number between 0 and 2^32-1", .{});
                return false;
              } 
              this.localSettings.maxHeaderListSize = @intCast(maxHeaderListSizeValue);
            } else if(!maxHeaderListSize.isEmptyOrUndefinedOrNull()) {
                globalObject.throw("Expected maxHeaderListSize to be a number", .{});
                return false;
            }
        }

          if(options.get(globalObject, "maxHeaderSize")) |maxHeaderSize| {
            if(maxHeaderSize.isNumber()) {
              const maxHeaderSizeValue = maxHeaderSize.toInt32();
              if(maxHeaderSizeValue > MAX_HEADER_TABLE_SIZE or maxHeaderSizeValue < 0) {
                globalObject.throw("Expected maxHeaderSize to be a number between 0 and 2^32-1", .{});
                return false;
              } 
              this.localSettings.maxHeaderListSize = @intCast(maxHeaderSizeValue);
            } else if(!maxHeaderSize.isEmptyOrUndefinedOrNull()) {
                globalObject.throw("Expected maxHeaderSize to be a number", .{});
                return false;
            }
        }
        return true;
    }

    pub fn updateSettings(this: *H2FrameParser, globalObject: *JSC.JSGlobalObject, callframe: *JSC.CallFrame) callconv(.C) JSValue {
        JSC.markBinding(@src());
        const args_list = callframe.arguments(1);
        if (args_list.len < 1) {
            globalObject.throw("Expected settings argument", .{});
            return .zero;
        }

        const options = args_list.ptr[0];

        if(this.loadSettingsFromJSValue(globalObject, options)) {     
            this.setSettings(this.localSettings);
            return JSC.JSValue.jsUndefined();
        }

        return .zero;

        
    }

    pub fn getCurrentState(this: *H2FrameParser, globalObject: *JSC.JSGlobalObject, _: *JSC.CallFrame) callconv(.C) JSValue {
        JSC.markBinding(@src());
        var result = JSValue.createEmptyObject(globalObject, 9);
        result.put(globalObject, JSC.ZigString.static("effectiveLocalWindowSize"), JSC.JSValue.jsNumber(this.windowSize));
        result.put(globalObject, JSC.ZigString.static("effectiveRecvDataLength"), JSC.JSValue.jsNumber(this.windowSize - this.usedWindowSize));
        result.put(globalObject, JSC.ZigString.static("nextStreamID"), JSC.JSValue.jsNumber(this.getNextStreamID()));
        result.put(globalObject, JSC.ZigString.static("lastProcStreamID"), JSC.JSValue.jsNumber(this.lastStreamID));


        var settings = this.remoteSettings orelse this.localSettings;
        result.put(globalObject, JSC.ZigString.static("remoteWindowSize"), JSC.JSValue.jsNumber(settings.initialWindowSize));
        result.put(globalObject, JSC.ZigString.static("localWindowSize"), JSC.JSValue.jsNumber(this.localSettings.initialWindowSize));
        result.put(globalObject, JSC.ZigString.static("deflateDynamicTableSize"), JSC.JSValue.jsNumber(settings.headerTableSize));
        result.put(globalObject, JSC.ZigString.static("inflateDynamicTableSize"), JSC.JSValue.jsNumber(settings.headerTableSize));


        // TODO: make this  real?
        result.put(globalObject, JSC.ZigString.static("outboundQueueSize"), JSC.JSValue.jsNumber(0));
        return result;
    }
    pub fn goaway(this: *H2FrameParser, globalObject: *JSC.JSGlobalObject, callframe: *JSC.CallFrame) callconv(.C) JSValue {
        JSC.markBinding(@src());
        const args_list = callframe.arguments(3);
        if (args_list.len < 1) {
            globalObject.throw("Expected errorCode argument", .{});
            return .zero;
        }

        const error_code_arg = args_list.ptr[0];

        if (!error_code_arg.isNumber()) {
            globalObject.throw("Expected errorCode to be a number", .{});
            return .zero;
        }
        const errorCode = error_code_arg.toInt32();
        if (errorCode < 1 and errorCode > 13) {
            globalObject.throw("invalid errorCode", .{});
        }

        var lastStreamID = this.lastStreamID;
        if(args_list.len >= 2) {
            const last_stream_arg = args_list.ptr[1];
            if(!last_stream_arg.isEmptyOrUndefinedOrNull()) {
                if (!last_stream_arg.isNumber()) {
                    globalObject.throw("Expected lastStreamId to be a number", .{});
                    return .zero;
                }   
                const id = last_stream_arg.toInt32();
                if(id < 0 and id > MAX_STREAM_ID) {
                   globalObject.throw("Expected lastStreamId to be a number between 1 and 2147483647", .{});
                   return .zero;
                }
                lastStreamID = @intCast(id);
            }
            if(args_list.len >= 3) {
                const opaque_data_arg = args_list.ptr[2];
                if(!opaque_data_arg.isEmptyOrUndefinedOrNull()) {
                    if (opaque_data_arg.asArrayBuffer(globalObject)) |array_buffer| {
                        var slice = array_buffer.slice();
                        this.sendGoAway(0, @enumFromInt(errorCode), slice, lastStreamID);
                        globalObject.throw("Expected lastStreamId to be a number", .{});
                        return .zero;
                    }   
                    const id = last_stream_arg.toInt32();
                    if(id < 0 and id > MAX_STREAM_ID) {
                       globalObject.throw("Expected lastStreamId to be a number between 1 and 2147483647", .{});
                       return .zero;
                    }
                }
            } 
        }

        this.sendGoAway(0, @enumFromInt(errorCode), "", lastStreamID);
        return JSC.JSValue.jsUndefined();
    }

    pub fn ping(this: *H2FrameParser, globalObject: *JSC.JSGlobalObject, callframe: *JSC.CallFrame) callconv(.C) JSValue {
        JSC.markBinding(@src());
        const args_list = callframe.arguments(1);
        if (args_list.len < 1) {
            globalObject.throw("Expected payload argument", .{});
            return .zero;
        }

        if (args_list.ptr[0].asArrayBuffer(globalObject)) |array_buffer| {
            var slice = array_buffer.slice();
            this.sendPing(false, slice);
            return JSC.JSValue.jsUndefined();
        } 

        globalObject.throw("Expected payload to be a Buffer", .{});
        return .zero;
    }
    // pub fn writeStream(this: *H2FrameParser, globalObject: *JSC.JSGlobalObject, callframe: *JSC.CallFrame) callconv(.C) JSValue {
    //     JSC.markBinding(@src());
    //     const args_list = callframe.arguments(2);
    //     if (args_list.len < 2) {
    //         globalObject.throw("Expected stream and data arguments", .{});
    //         return .zero;
    //     }
    //     var close_stream = false;
    //     if(args_list > 2) {
    //         const close_arg = args_list.ptr[2];
    //         if (!close_arg.jsType().isBoolean()) {
    //             globalObject.throw("Expected close to be a boolean", .{});
    //             return .zero;
    //         }
    //         close_stream = close_arg.asBoolean();
    //     }

    //     const stream_arg = args_list.ptr[0];
    //     const data_arg = args_list.ptr[1];

    //     if (!stream_arg.isNumber()) {
    //         globalObject.throw("Expected stream to be a number", .{});
    //         return .zero;
    //     }

    //     const stream_id = stream_arg.asNumber().asUInt32(globalObject);
    //     if (stream_id == 0) {
    //         globalObject.throw("Invalid stream id", .{});
    //         return .zero;
    //     }

    //     const stream = this.streams.get(stream_id) orelse {
    //         globalObject.throw("Invalid stream id", .{});
    //         return .zero;
    //     };

    //     if (stream.state == .CLOSED) {
    //         globalObject.throw("Stream is closed", .{});
    //         return .zero;
    //     }

    //     if (stream.state == .HALF_CLOSED_LOCAL or stream.state == .HALF_CLOSED_REMOTE) {
    //         globalObject.throw("Stream is half closed", .{});
    //         return .zero;
    //     }

    //     if (data_arg.asArrayBuffer(globalObject)) |array_buffer| {
    //         var slice = array_buffer.slice();
    //     } else if (bun.String.tryFromJS(data_arg, globalObject)) |bun_str| {
    //         var zig_str = bun_str.toUTF8(bun.default_allocator);
    //         defer zig_str.deinit();
    //         var slice = zig_str.slice();

    //     } else {
    //         globalObject.throw("Expected data to be an ArrayBuffer or a string", .{});
    //         return .zero;
    //     }

    //     return JSC.JSValue.jsBoolean(true);
    // }

    fn getNextStreamID(this: *H2FrameParser) u32 {
        var stream_id: u32 = this.lastStreamID;
        if (stream_id % 2 == 0) {
            stream_id += 1;
        } else if (stream_id == 0) {
            stream_id = 1;
        } else {
            stream_id += 2;
        }
        
        return stream_id;
    }

    pub fn request(this: *H2FrameParser, globalObject: *JSC.JSGlobalObject, callframe: *JSC.CallFrame) callconv(.C) JSValue {
        JSC.markBinding(@src());
        // we use PADDING_STRATEGY_NONE with is default
        // TODO: PADDING_STRATEGY_MAX AND PADDING_STRATEGY_ALIGNED

        const args_list = callframe.arguments(2);
        if (args_list.len < 1) {
            globalObject.throw("Expected headers argument", .{});
            return .zero;
        }

        const headers_arg = args_list.ptr[0];

        if (!headers_arg.jsType().isArray()) {
            globalObject.throw("Expected headers to be an array", .{});
            return .zero;
        }

        // max frame size will be always at least 16384
        var buffer: [16384 - FrameHeader.byteSize - 5]u8 = undefined;
        var header_buffer: [MAX_HPACK_HEADER_SIZE]u8 = undefined;
        @memset(&buffer, 0);

        var iter = headers_arg.arrayIterator(globalObject);
        var encoded_size: usize = 0;

        var stream_id: u32 = this.getNextStreamID();
        if (stream_id > MAX_STREAM_ID) {
            globalObject.throw("Failed to create stream", .{});
            return .zero;
        }

        const stream = this.handleReceivedStreamID(stream_id) orelse {
            globalObject.throw("Failed to create stream", .{});
            return .zero;
        };
        // TODO: support CONTINUE for more headers if headers are too big
        while (iter.next()) |header| {
            if (!header.isObject()) {
                stream.state = .CLOSED;
                stream.rstCode = @intFromEnum(ErrorCode.INTERNAL_ERROR);
                this.dispatchWithExtra(.onStreamError, JSC.JSValue.jsNumber(stream_id), JSC.JSValue.jsNumber(stream.rstCode));
                globalObject.throwInvalidArguments("Expected header to be an Array of headers", .{});
                return .zero;
            }
            var name = header.get(globalObject, "name") orelse JSC.JSValue.jsUndefined();
            if (!name.isString()) {
                stream.state = .CLOSED;
                stream.rstCode = @intFromEnum(ErrorCode.INTERNAL_ERROR);
                this.dispatchWithExtra(.onStreamError, JSC.JSValue.jsNumber(stream_id), JSC.JSValue.jsNumber(stream.rstCode));
                globalObject.throwInvalidArguments("Expected header name to be a string", .{});
                return .zero;
            }

            var value = header.get(globalObject, "value") orelse JSC.JSValue.jsUndefined();
            if (!value.isString()) {
                stream.state = .CLOSED;
                stream.rstCode = @intFromEnum(ErrorCode.INTERNAL_ERROR);
                this.dispatchWithExtra(.onStreamError, JSC.JSValue.jsNumber(stream_id), JSC.JSValue.jsNumber(stream.rstCode));
                globalObject.throwInvalidArguments("Expected header value to be a string", .{});
                return .zero;
            }

            var never_index = false;
            var never_index_arg = header.get(globalObject, "neverIndex") orelse JSC.JSValue.jsUndefined();
            if (never_index_arg.isBoolean()) {
                never_index = never_index_arg.asBoolean();
            } else {
                never_index = false;
            }

            const name_slice = name.toSlice(globalObject, bun.default_allocator);
            defer name_slice.deinit();
            const value_slice = value.toSlice(globalObject, bun.default_allocator);
            defer value_slice.deinit();

            encoded_size += stream.encode(&header_buffer, buffer[encoded_size..], name_slice.slice(), value_slice.slice(), never_index) catch {
                stream.state = .CLOSED;
                stream.rstCode = @intFromEnum(ErrorCode.INTERNAL_ERROR);
                this.dispatchWithExtra(.onStreamError, JSC.JSValue.jsNumber(stream_id), JSC.JSValue.jsNumber(stream.rstCode));
                globalObject.throw("Failed to encode header", .{});
                return .zero;
            };
        }
        headers_arg.protect();
        stream.sentHeaders = headers_arg;
        var flags: u8 = @intFromEnum(HeadersFrameFlags.END_HEADERS);
        var exclusive: bool = false;
        var has_priority: bool = false;
        var weight: i32 = 0;
        var parent: i32 = 0;
        var waitForTrailers: bool = false;
        var signal: ?*JSC.WebCore.AbortSignal = null;
        var end_stream: bool = false;
        if (args_list.len > 1) {
            const options = args_list.ptr[1];
            if (!options.isObject()) {
                stream.state = .CLOSED;
                stream.rstCode = @intFromEnum(ErrorCode.INTERNAL_ERROR);
                this.dispatchWithExtra(.onStreamError, JSC.JSValue.jsNumber(stream_id), JSC.JSValue.jsNumber(stream.rstCode));
                globalObject.throw("Expected options to be an object", .{});
                return .zero;
            }

            if (options.get(globalObject, "endStream")) |end_stream_js| {
                if (end_stream_js.isBoolean()) {
                    if (end_stream_js.asBoolean()) {
                        end_stream = true;
                        flags |= @intFromEnum(HeadersFrameFlags.END_STREAM);
                        stream.endAfterHeaders = true;
                    }
                }
            }

            if (options.get(globalObject, "exclusive")) |exclusive_js| {
                if (exclusive_js.isBoolean()) {
                    if (exclusive_js.asBoolean()) {
                        exclusive = true;
                        stream.exclusive = true;
                        has_priority = true;
                    }
                }
            }

            if (options.get(globalObject, "parent")) |parent_js| {
                if (parent_js.isNumber() or parent_js.isInt32()) {
                    has_priority = true;
                    parent = parent_js.toInt32();
                    if (parent <= 0 or parent > MAX_STREAM_ID) {
                        stream.state = .CLOSED;
                        stream.rstCode = @intFromEnum(ErrorCode.INTERNAL_ERROR);
                        this.dispatchWithExtra(.onStreamError, JSC.JSValue.jsNumber(stream_id), JSC.JSValue.jsNumber(stream.rstCode));
                        globalObject.throw("Expected parent to be a number between 1 and 2147483647", .{});
                        return .zero;
                    }
                    stream.streamDependency = @intCast(parent);
                }
            }

            if (options.get(globalObject, "weight")) |weight_js| {
                if (weight_js.isNumber() or weight_js.isInt32()) {
                    has_priority = true;
                    weight = weight_js.toInt32();
                    if (weight < 1 or weight > 256) {
                        stream.state = .CLOSED;
                        stream.rstCode = @intFromEnum(ErrorCode.INTERNAL_ERROR);
                        this.dispatchWithExtra(.onStreamError, JSC.JSValue.jsNumber(stream_id), JSC.JSValue.jsNumber(stream.rstCode));
                        globalObject.throw("Expected weight to be a number between 1 and 256", .{});
                        return .zero;
                    }
                    stream.weight = @intCast(weight);
                }

                if (weight < 1 or weight > 256) {
                    stream.state = .CLOSED;
                    stream.rstCode = @intFromEnum(ErrorCode.INTERNAL_ERROR);
                    this.dispatchWithExtra(.onStreamError, JSC.JSValue.jsNumber(stream_id), JSC.JSValue.jsNumber(stream.rstCode));
                    globalObject.throw("Expected weight to be a number between 1 and 256", .{});
                    return .zero;
                }
                stream.weight = @intCast(weight);
            }

            if (options.get(globalObject, "waitForTrailers")) |trailes_js| {
                if (trailes_js.isBoolean()) {
                    waitForTrailers = trailes_js.asBoolean();
                    stream.waitForTrailers = waitForTrailers;
                }
            }

            if (options.get(globalObject, "signal")) |signal_arg| {
                if (signal_arg.as(JSC.WebCore.AbortSignal)) |signal_| {
                    signal = signal_;
                }
            }
        }

        if (signal) |signal_| {
            stream.attachSignal(signal_);
        }

        var length: usize = encoded_size;
        if (has_priority) {
            length += 5;
            flags |= @intFromEnum(HeadersFrameFlags.PRIORITY);
        }

        log("request encoded_size {}", .{encoded_size});
        var frame: FrameHeader = .{
            .type = @intFromEnum(FrameType.HTTP_FRAME_HEADERS),
            .flags = flags,
            .streamIdentifier = stream.id,
            .length = @intCast(encoded_size),
        };
        var writer = this.toWriter();
        frame.write(@TypeOf(writer), writer);
        //https://datatracker.ietf.org/doc/html/rfc7540#section-6.2
        if (has_priority) {
            var stream_identifier: UInt31WithReserved = .{
                .reserved = exclusive,
                .uint31 = @intCast(parent),
            };

            var priority: StreamPriority = .{
                .streamIdentifier = stream_identifier.toUInt32(),
                .weight = @intCast(weight),
            };

            priority.write(@TypeOf(writer), writer);
        }

        this.write(buffer[0..encoded_size]);

        if (end_stream) {
            stream.state = .HALF_CLOSED_LOCAL;

            if (waitForTrailers) {
                this.dispatch(.onWantTrailers, JSC.JSValue.jsNumber(stream.id));
            }
        }

        return JSC.JSValue.jsNumber(stream.id);
    }

    pub fn read(this: *H2FrameParser, globalObject: *JSC.JSGlobalObject, callframe: *JSC.CallFrame) callconv(.C) JSValue {
        JSC.markBinding(@src());
        const args_list = callframe.arguments(1);
        if (args_list.len < 1) {
            globalObject.throw("Expected 1 argument", .{});
            return .zero;
        }
        const buffer = args_list.ptr[0];
        if (buffer.asArrayBuffer(globalObject)) |array_buffer| {
            var bytes = array_buffer.slice();

            // read all the bytes
            while (bytes.len > 0) {
                const result = this.readBytes(bytes);
                if (result >= bytes.len) {
                    break;
                }
                bytes = bytes[result..];
            }
            return JSC.JSValue.jsUndefined();
        }
        globalObject.throw("Expected data to be a Buffer or ArrayBuffer", .{});
        return .zero;
    }

    pub fn constructor(globalObject: *JSC.JSGlobalObject, callframe: *JSC.CallFrame) callconv(.C) ?*H2FrameParser {
        const args_list = callframe.arguments(1);
        if (args_list.len < 1) {
            globalObject.throw("Expected 1 argument", .{});
            return null;
        }

        const options = args_list.ptr[0];
        if (options.isEmptyOrUndefinedOrNull() or options.isBoolean() or !options.isObject()) {
            globalObject.throwInvalidArguments("expected options as argument", .{});
            return null;
        }

        var exception: JSC.C.JSValueRef = null;
        var context_obj = options.get(globalObject, "context") orelse {
            globalObject.throw("Expected \"context\" option", .{});
            return null;
        };
        var handler_js = JSC.JSValue.zero;
        if(options.get(globalObject, "handlers")) |handlers_| {
            handler_js = handlers_;
        }
        const handlers = Handlers.fromJS(globalObject, handler_js, &exception) orelse {
            globalObject.throwValue(exception.?.value());
            return null;
        };

        
        const allocator = getAllocator(globalObject);
        var this = allocator.create(H2FrameParser) catch unreachable;

        this.* = H2FrameParser{
            .handlers = handlers,
            .allocator = allocator,
            .readBuffer = .{
                .allocator = bun.default_allocator,
                .list = .{
                    .items = &.{},
                    .capacity = 0,
                },
            },
            .streams = bun.U32HashMap(Stream).init(bun.default_allocator),
        };
        if(options.get(globalObject, "settings")) |settings_js| {
            if(!settings_js.isEmptyOrUndefinedOrNull()) {
                if(!this.loadSettingsFromJSValue(globalObject, settings_js)) {
                    this.deinit();
                    return null;
                }
            }
        }
        this.handlers.protect();

        this.strong_ctx.set(globalObject, context_obj);

        this.sendPrefaceAndSettings();
        return this;
    }

    pub fn deinit(this: *H2FrameParser) void {
        var allocator = this.allocator;
        defer allocator.destroy(this);
        this.strong_ctx.deinit();
        this.handlers.unprotect();
        this.readBuffer.deinit();

        var it = this.streams.iterator();
        while (it.next()) |*entry| {
            var stream = entry.value_ptr.*;
            stream.deinit();
        }

        this.streams.deinit();
    }

    pub fn finalize(
        this: *H2FrameParser,
    ) callconv(.C) void {
        this.deinit();
    }
};
