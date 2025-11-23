const fs = require('fs');
const path = require('path');

let instance;
const decoder = new TextDecoder();
const encoder = new TextEncoder();
const charBuffer = Buffer.alloc(1);
let outputBuffer = '';

function readMem(index, size) {
    const memory = new Uint8Array(instance.exports.memory.buffer);
    const buffer = memory.subarray(index, index + size);
    return buffer;
}

const env = {
    env: {
        print_mem: (index, size) => {
            const buffer = readMem(index, size);
            const string = decoder.decode(buffer);
            process.stdout.write(string);
            outputBuffer += string;
        },

        print_val: (val) => {
            outputBuffer += val.toString();
        },

        print_char: (val) => {
            const char = String.fromCharCode(val);
            outputBuffer += char;
        },

        read_char: () => {
            fs.readSync(process.stdin.fd, charBuffer, 0, 1);
            return charBuffer.toString().charCodeAt(0);
        },

        read_file: (fileNameIndex, fileNameSize, index, maxSize) => {
            const fileName = readMem(fileNameIndex, fileNameSize);
            const input = fs.readFileSync(fileName);

            const buffer = encoder.encode(input);

            if (maxSize < input.length) {
                buffer = buffer.subarray(0, maxSize);
            }

            new Uint8Array(instance.exports.memory.buffer).set(buffer, index);
            return buffer.length;
        }
    }
};

const wasmPath = path.resolve(__dirname, 'dist/main.wasm');

fs.promises.readFile(wasmPath)
    .then(bytes => WebAssembly.instantiate(bytes, env))
    .then(result => {
        instance = result.instance;
        const exports = instance.exports;

        exports.main();
        console.log(outputBuffer);
    })
    .catch(console.error);
