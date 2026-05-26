// main.swift — PLAIN transpiler entry point

import Foundation

struct CompileError: Error {
    let message: String
}

func usage() {
    print("""
    plain <command> [options] <file>

    Commands:
      build <file>     Transpile and compile to a native binary
      run <file>       Transpile, compile, and run
      transpile <file> Transpile to C only
      check <file>     Check syntax without compiling

    Options:
      --output, -o <path>   Output binary path (default: <file without extension>)
      --keep-c              Keep the generated C file after compilation
      --version             Print version
      --help                Print this message
    """)
}

func main() {
    let args = CommandLine.arguments
    guard args.count >= 2 else { usage(); exit(1) }

    let command = args[1]

    switch command {
    case "--version":
        print("plain 0.1.0")

    case "--help", "-h":
        usage()

    case "transpile":
        guard args.count >= 3 else { print("Usage: plain transpile <file>"); exit(1) }
        let path = args[2]
        do {
            let c = try transpileFile(at: path)
            print(c)
        } catch let e as LexerError {
            printError("Lexer error at \(e.line):\(e.column): \(e.message)")
            exit(1)
        } catch let e as ParseError {
            printError("Parse error at \(e.line):\(e.column): \(e.message)")
            exit(1)
        } catch {
            printError("Error: \(error)")
            exit(1)
        }

    case "check":
        guard args.count >= 3 else { print("Usage: plain check <file>"); exit(1) }
        let path = args[2]
        do {
            _ = try transpileFile(at: path)
            print("✓ \(path)")
        } catch let e as LexerError {
            printError("\(path):\(e.line):\(e.column): \(e.message)")
            exit(1)
        } catch let e as ParseError {
            printError("\(path):\(e.line):\(e.column): \(e.message)")
            exit(1)
        } catch {
            printError("Error: \(error)")
            exit(1)
        }

    case "build", "run":
        guard args.count >= 3 else { print("Usage: plain \(command) <file>"); exit(1) }
        let inputPath = args[2]
        let keepC     = args.contains("--keep-c")
        var outputPath = URL(fileURLWithPath: inputPath).deletingPathExtension().lastPathComponent
        if let oIdx = args.firstIndex(of: "--output") ?? args.firstIndex(of: "-o"), args.count > oIdx + 1 {
            outputPath = args[oIdx + 1]
        }

        do {
            let cSource = try transpileFile(at: inputPath)
            let cPath   = outputPath + ".c"
            let runtimeDir = findRuntimeDir()

            try cSource.write(toFile: cPath, atomically: true, encoding: .utf8)

            let runtimeH = runtimeDir + "/plain_runtime.h"
            let runtimeC = runtimeDir + "/plain_runtime.c"

            let cc = Process()
            cc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            cc.arguments     = ["cc", "-O2", "-o", outputPath, cPath, runtimeC,
                                 "-I", runtimeDir, "-lcurl", "-lm", "-lpthread"]
            cc.launch()
            cc.waitUntilExit()

            if !keepC { try? FileManager.default.removeItem(atPath: cPath) }

            guard cc.terminationStatus == 0 else {
                printError("Compilation failed.")
                exit(1)
            }

            if command == "run" {
                let run = Process()
                run.executableURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/" + outputPath)
                run.launch()
                run.waitUntilExit()
                exit(run.terminationStatus)
            }

        } catch let e as LexerError {
            printError("\(inputPath):\(e.line):\(e.column): \(e.message)")
            exit(1)
        } catch let e as ParseError {
            printError("\(inputPath):\(e.line):\(e.column): \(e.message)")
            exit(1)
        } catch {
            printError("Error: \(error)")
            exit(1)
        }

    default:
        print("Unknown command '\(command)'")
        usage()
        exit(1)
    }
}

func transpileFile(at path: String) throws -> String {
    let source = try String(contentsOfFile: path, encoding: .utf8)
    var lexer  = Lexer(source: source)
    let tokens = try lexer.tokenise()
    var parser = Parser(tokens: tokens)
    let ast    = try parser.parse()
    var gen    = CGenerator()
    return gen.generate(program: ast)
}

func findRuntimeDir() -> String {
    // Look relative to the binary, then a few common install locations
    let candidates = [
        URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
            .appendingPathComponent("../Runtime")
            .standardized.path,
        "/usr/local/lib/plain/runtime",
        "/usr/lib/plain/runtime",
    ]
    return candidates.first {
        FileManager.default.fileExists(atPath: $0 + "/plain_runtime.h")
    } ?? candidates[0]
}

func printError(_ message: String) {
    var stderr = FileHandle.standardError
    let data   = (message + "\n").data(using: .utf8)!
    stderr.write(data)
}

main()
