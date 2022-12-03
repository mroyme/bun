/*
 * Copyright (c) 2015 Igalia
 * Copyright (c) 2015 Igalia S.L.
 * Copyright (c) 2015 Igalia.
 * Copyright (c) 2015, 2016 Canon Inc. All rights reserved.
 * Copyright (c) 2015, 2016, 2017 Canon Inc.
 * Copyright (c) 2016, 2018 -2018 Apple Inc. All rights reserved.
 * Copyright (c) 2016, 2020 Apple Inc. All rights reserved.
 * Copyright (c) 2022 Codeblog Corp. All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 * 
 */

// DO NOT EDIT THIS FILE. It is automatically generated from JavaScript files for
// builtins by the script: Source/JavaScriptCore/Scripts/generate-js-builtins.py

#pragma once

#include "ByteLengthQueuingStrategyBuiltins.h"
#include "CountQueuingStrategyBuiltins.h"
#include "ImportMetaObjectBuiltins.h"
#include "JSBufferConstructorBuiltins.h"
#include "JSBufferPrototypeBuiltins.h"
#include "OnigurumaRegExpPrototypeBuiltins.h"
#include "ProcessObjectInternalsBuiltins.h"
#include "ReadableByteStreamControllerBuiltins.h"
#include "ReadableByteStreamInternalsBuiltins.h"
#include "ReadableStreamBYOBReaderBuiltins.h"
#include "ReadableStreamBYOBRequestBuiltins.h"
#include "ReadableStreamBuiltins.h"
#include "ReadableStreamDefaultControllerBuiltins.h"
#include "ReadableStreamDefaultReaderBuiltins.h"
#include "ReadableStreamInternalsBuiltins.h"
#include "StreamInternalsBuiltins.h"
#include "TransformStreamBuiltins.h"
#include "TransformStreamDefaultControllerBuiltins.h"
#include "TransformStreamInternalsBuiltins.h"
#include "WritableStreamDefaultControllerBuiltins.h"
#include "WritableStreamDefaultWriterBuiltins.h"
#include "WritableStreamInternalsBuiltins.h"
#include <JavaScriptCore/VM.h>

namespace WebCore {

class JSBuiltinFunctions {
public:
    explicit JSBuiltinFunctions(JSC::VM& vm)
        : m_vm(vm)
        , m_byteLengthQueuingStrategyBuiltins(m_vm)
        , m_countQueuingStrategyBuiltins(m_vm)
        , m_importMetaObjectBuiltins(m_vm)
        , m_jsBufferConstructorBuiltins(m_vm)
        , m_jsBufferPrototypeBuiltins(m_vm)
        , m_onigurumaRegExpPrototypeBuiltins(m_vm)
        , m_processObjectInternalsBuiltins(m_vm)
        , m_readableByteStreamControllerBuiltins(m_vm)
        , m_readableByteStreamInternalsBuiltins(m_vm)
        , m_readableStreamBuiltins(m_vm)
        , m_readableStreamBYOBReaderBuiltins(m_vm)
        , m_readableStreamBYOBRequestBuiltins(m_vm)
        , m_readableStreamDefaultControllerBuiltins(m_vm)
        , m_readableStreamDefaultReaderBuiltins(m_vm)
        , m_readableStreamInternalsBuiltins(m_vm)
        , m_streamInternalsBuiltins(m_vm)
        , m_transformStreamBuiltins(m_vm)
        , m_transformStreamDefaultControllerBuiltins(m_vm)
        , m_transformStreamInternalsBuiltins(m_vm)
        , m_writableStreamDefaultControllerBuiltins(m_vm)
        , m_writableStreamDefaultWriterBuiltins(m_vm)
        , m_writableStreamInternalsBuiltins(m_vm)
    {
        m_processObjectInternalsBuiltins.exportNames();
        m_readableByteStreamInternalsBuiltins.exportNames();
        m_readableStreamInternalsBuiltins.exportNames();
        m_streamInternalsBuiltins.exportNames();
        m_transformStreamInternalsBuiltins.exportNames();
        m_writableStreamInternalsBuiltins.exportNames();
    }

    ByteLengthQueuingStrategyBuiltinsWrapper& byteLengthQueuingStrategyBuiltins() { return m_byteLengthQueuingStrategyBuiltins; }
    CountQueuingStrategyBuiltinsWrapper& countQueuingStrategyBuiltins() { return m_countQueuingStrategyBuiltins; }
    ImportMetaObjectBuiltinsWrapper& importMetaObjectBuiltins() { return m_importMetaObjectBuiltins; }
    JSBufferConstructorBuiltinsWrapper& jsBufferConstructorBuiltins() { return m_jsBufferConstructorBuiltins; }
    JSBufferPrototypeBuiltinsWrapper& jsBufferPrototypeBuiltins() { return m_jsBufferPrototypeBuiltins; }
    OnigurumaRegExpPrototypeBuiltinsWrapper& onigurumaRegExpPrototypeBuiltins() { return m_onigurumaRegExpPrototypeBuiltins; }
    ProcessObjectInternalsBuiltinsWrapper& processObjectInternalsBuiltins() { return m_processObjectInternalsBuiltins; }
    ReadableByteStreamControllerBuiltinsWrapper& readableByteStreamControllerBuiltins() { return m_readableByteStreamControllerBuiltins; }
    ReadableByteStreamInternalsBuiltinsWrapper& readableByteStreamInternalsBuiltins() { return m_readableByteStreamInternalsBuiltins; }
    ReadableStreamBuiltinsWrapper& readableStreamBuiltins() { return m_readableStreamBuiltins; }
    ReadableStreamBYOBReaderBuiltinsWrapper& readableStreamBYOBReaderBuiltins() { return m_readableStreamBYOBReaderBuiltins; }
    ReadableStreamBYOBRequestBuiltinsWrapper& readableStreamBYOBRequestBuiltins() { return m_readableStreamBYOBRequestBuiltins; }
    ReadableStreamDefaultControllerBuiltinsWrapper& readableStreamDefaultControllerBuiltins() { return m_readableStreamDefaultControllerBuiltins; }
    ReadableStreamDefaultReaderBuiltinsWrapper& readableStreamDefaultReaderBuiltins() { return m_readableStreamDefaultReaderBuiltins; }
    ReadableStreamInternalsBuiltinsWrapper& readableStreamInternalsBuiltins() { return m_readableStreamInternalsBuiltins; }
    StreamInternalsBuiltinsWrapper& streamInternalsBuiltins() { return m_streamInternalsBuiltins; }
    TransformStreamBuiltinsWrapper& transformStreamBuiltins() { return m_transformStreamBuiltins; }
    TransformStreamDefaultControllerBuiltinsWrapper& transformStreamDefaultControllerBuiltins() { return m_transformStreamDefaultControllerBuiltins; }
    TransformStreamInternalsBuiltinsWrapper& transformStreamInternalsBuiltins() { return m_transformStreamInternalsBuiltins; }
    WritableStreamDefaultControllerBuiltinsWrapper& writableStreamDefaultControllerBuiltins() { return m_writableStreamDefaultControllerBuiltins; }
    WritableStreamDefaultWriterBuiltinsWrapper& writableStreamDefaultWriterBuiltins() { return m_writableStreamDefaultWriterBuiltins; }
    WritableStreamInternalsBuiltinsWrapper& writableStreamInternalsBuiltins() { return m_writableStreamInternalsBuiltins; }

private:
    JSC::VM& m_vm;
    ByteLengthQueuingStrategyBuiltinsWrapper m_byteLengthQueuingStrategyBuiltins;
    CountQueuingStrategyBuiltinsWrapper m_countQueuingStrategyBuiltins;
    ImportMetaObjectBuiltinsWrapper m_importMetaObjectBuiltins;
    JSBufferConstructorBuiltinsWrapper m_jsBufferConstructorBuiltins;
    JSBufferPrototypeBuiltinsWrapper m_jsBufferPrototypeBuiltins;
    OnigurumaRegExpPrototypeBuiltinsWrapper m_onigurumaRegExpPrototypeBuiltins;
    ProcessObjectInternalsBuiltinsWrapper m_processObjectInternalsBuiltins;
    ReadableByteStreamControllerBuiltinsWrapper m_readableByteStreamControllerBuiltins;
    ReadableByteStreamInternalsBuiltinsWrapper m_readableByteStreamInternalsBuiltins;
    ReadableStreamBuiltinsWrapper m_readableStreamBuiltins;
    ReadableStreamBYOBReaderBuiltinsWrapper m_readableStreamBYOBReaderBuiltins;
    ReadableStreamBYOBRequestBuiltinsWrapper m_readableStreamBYOBRequestBuiltins;
    ReadableStreamDefaultControllerBuiltinsWrapper m_readableStreamDefaultControllerBuiltins;
    ReadableStreamDefaultReaderBuiltinsWrapper m_readableStreamDefaultReaderBuiltins;
    ReadableStreamInternalsBuiltinsWrapper m_readableStreamInternalsBuiltins;
    StreamInternalsBuiltinsWrapper m_streamInternalsBuiltins;
    TransformStreamBuiltinsWrapper m_transformStreamBuiltins;
    TransformStreamDefaultControllerBuiltinsWrapper m_transformStreamDefaultControllerBuiltins;
    TransformStreamInternalsBuiltinsWrapper m_transformStreamInternalsBuiltins;
    WritableStreamDefaultControllerBuiltinsWrapper m_writableStreamDefaultControllerBuiltins;
    WritableStreamDefaultWriterBuiltinsWrapper m_writableStreamDefaultWriterBuiltins;
    WritableStreamInternalsBuiltinsWrapper m_writableStreamInternalsBuiltins;
};

} // namespace WebCore
