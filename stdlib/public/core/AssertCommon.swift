//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// Implementation Note: this file intentionally uses very LOW-LEVEL
// CONSTRUCTS, so that assert and fatal may be used liberally in
// building library abstractions without fear of infinite recursion.
//
// FIXME: We could go farther with this simplification, e.g. avoiding
// UnsafeMutablePointer

@_transparent
@warn_unused_result
public // @testable
func _isDebugAssertConfiguration() -> Bool {
  // The values for the assert_configuration call are:
  // 0: Debug
  // 1: Release
  // 2: Fast
  return Int32(Builtin.assert_configuration()) == 0
}

@_transparent
@warn_unused_result
internal func _isReleaseAssertConfiguration() -> Bool {
  // The values for the assert_configuration call are:
  // 0: Debug
  // 1: Release
  // 2: Fast
  return Int32(Builtin.assert_configuration()) == 1
}

@_transparent
@warn_unused_result
public // @testable
func _isFastAssertConfiguration() -> Bool {
  // The values for the assert_configuration call are:
  // 0: Debug
  // 1: Release
  // 2: Fast
  return Int32(Builtin.assert_configuration()) == 2
}

@_transparent
@warn_unused_result
public // @testable
func _isStdlibInternalChecksEnabled() -> Bool {
#if INTERNAL_CHECKS_ENABLED
  return true
#else
  return false
#endif
}

@_transparent
@warn_unused_result
internal
func _fatalErrorFlags() -> UInt32 {
  // The current flags are:
  // (1 << 0): Report backtrace on fatal error
#if os(iOS) || os(tvOS) || os(watchOS)
  return 0
#else
  return _isDebugAssertConfiguration() ? 1 : 0
#endif
}

@_silgen_name("_swift_stdlib_reportFatalErrorInFile")
func _reportFatalErrorInFile(
  prefix: UnsafePointer<UInt8>, _ prefixLength: UInt,
  _ message: UnsafePointer<UInt8>, _ messageLength: UInt,
  _ file: UnsafePointer<UInt8>, _ fileLength: UInt,
  _ line: UInt, flags: UInt32)

@_silgen_name("_swift_stdlib_reportFatalError")
func _reportFatalError(
  prefix: UnsafePointer<UInt8>, _ prefixLength: UInt,
  _ message: UnsafePointer<UInt8>, _ messageLength: UInt,
  flags: UInt32)

@_silgen_name("_swift_stdlib_reportUnimplementedInitializerInFile")
func _reportUnimplementedInitializerInFile(
  className: UnsafePointer<UInt8>, _ classNameLength: UInt,
  _ initName: UnsafePointer<UInt8>, _ initNameLength: UInt,
  _ file: UnsafePointer<UInt8>, _ fileLength: UInt,
  _ line: UInt, _ column: UInt,
  flags: UInt32)

@_silgen_name("_swift_stdlib_reportUnimplementedInitializer")
func _reportUnimplementedInitializer(
  className: UnsafePointer<UInt8>, _ classNameLength: UInt,
  _ initName: UnsafePointer<UInt8>, _ initNameLength: UInt,
  flags: UInt32)

/// This function should be used only in the implementation of user-level
/// assertions.
///
/// This function should not be inlined because it is cold and inlining just
/// bloats code.
@noreturn @inline(never)
@_semantics("stdlib_binary_only")
func _assertionFailed(
  prefix: StaticString, _ message: StaticString,
  _ file: StaticString, _ line: UInt,
  flags: UInt32
) {
  prefix.withUTF8Buffer {
    (prefix) -> Void in
    message.withUTF8Buffer {
      (message) -> Void in
      file.withUTF8Buffer {
        (file) -> Void in
        _reportFatalErrorInFile(
          prefix.baseAddress, UInt(prefix.count),
          message.baseAddress, UInt(message.count),
          file.baseAddress, UInt(file.count), line,
          flags: flags)
        Builtin.int_trap()
      }
    }
  }
  Builtin.int_trap()
}

/// This function should be used only in the implementation of user-level
/// assertions.
///
/// This function should not be inlined because it is cold and inlining just
/// bloats code.
@noreturn @inline(never)
@_semantics("stdlib_binary_only")
func _assertionFailed(
  prefix: StaticString, _ message: String,
  _ file: StaticString, _ line: UInt,
  flags: UInt32
) {
  prefix.withUTF8Buffer {
    (prefix) -> Void in
    let messageUTF8 = message.nulTerminatedUTF8
    messageUTF8.withUnsafeBufferPointer {
      (messageUTF8) -> Void in
      file.withUTF8Buffer {
        (file) -> Void in
        _reportFatalErrorInFile(
          prefix.baseAddress, UInt(prefix.count),
          messageUTF8.baseAddress, UInt(messageUTF8.count),
          file.baseAddress, UInt(file.count), line,
          flags: flags)
      }
    }
  }

  Builtin.int_trap()
}

/// This function should be used only in the implementation of stdlib
/// assertions.
///
/// This function should not be inlined because it is cold and it inlining just
/// bloats code.
@noreturn @inline(never)
@_semantics("stdlib_binary_only")
@_semantics("arc.programtermination_point")
func _fatalErrorMessage(
  prefix: StaticString, _ message: StaticString,
  _ file: StaticString, _ line: UInt,
  flags: UInt32
) {
#if INTERNAL_CHECKS_ENABLED
  prefix.withUTF8Buffer {
    (prefix) in
    message.withUTF8Buffer {
      (message) in
      file.withUTF8Buffer {
        (file) in
        _reportFatalErrorInFile(
          prefix.baseAddress, UInt(prefix.count),
          message.baseAddress, UInt(message.count),
          file.baseAddress, UInt(file.count), line,
          flags: flags)
      }
    }
  }
#else
  prefix.withUTF8Buffer {
    (prefix) in
    message.withUTF8Buffer {
      (message) in
      _reportFatalError(
        prefix.baseAddress, UInt(prefix.count),
        message.baseAddress, UInt(message.count),
        flags: flags)
    }
  }
#endif

  Builtin.int_trap()
}

/// Prints a fatal error message when an unimplemented initializer gets
/// called by the Objective-C runtime.
@_transparent @noreturn
public // COMPILER_INTRINSIC
func _unimplemented_initializer(className: StaticString,
                                initName: StaticString = #function,
                                file: StaticString = #file,
                                line: UInt = #line,
                                column: UInt = #column) {
  // This function is marked @_transparent so that it is inlined into the caller
  // (the initializer stub), and, depending on the build configuration,
  // redundant parameter values (#file etc.) are eliminated, and don't leak
  // information about the user's source.

  if _isDebugAssertConfiguration() {
    className.withUTF8Buffer {
      (className) in
      initName.withUTF8Buffer {
        (initName) in
        file.withUTF8Buffer {
          (file) in
          _reportUnimplementedInitializerInFile(
            className.baseAddress, UInt(className.count),
            initName.baseAddress, UInt(initName.count),
            file.baseAddress, UInt(file.count), line, column,
            flags: 0)
        }
      }
    }
  } else {
    className.withUTF8Buffer {
      (className) in
      initName.withUTF8Buffer {
        (initName) in
        _reportUnimplementedInitializer(
          className.baseAddress, UInt(className.count),
          initName.baseAddress, UInt(initName.count),
          flags: 0)
      }
    }
  }

  Builtin.int_trap()
}

@noreturn
public // COMPILER_INTRINSIC
func _undefined<T>(
  @autoclosure message: () -> String = String(),
  file: StaticString = #file, line: UInt = #line
) -> T {
  _assertionFailed("fatal error", message(), file, line,
    flags: 0)
}
