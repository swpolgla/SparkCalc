# SparkCalc

A modern, live-evaluating calculator for macOS.

Type equations in the left pane and see answers appear instantly in the right pane. Define variables and functions that cascade down the sheet. Everything updates in real time.

---

## Features

- **Live evaluation** — Results update as you type
- **Variables** — Assign names to values and reuse them later in the sheet
- **User-defined functions** — Multi-line functions with local parameters and variables
- **Built-in constants** — `pi`, `e`, `phi`, `tau`, and scientific constants (`c`, `G`, `h`, etc.)
- **Built-in functions** — Full trig suite, logarithms, roots, powers, min/max, and more
- **Syntax highlighting** — Variables, functions, and operators are color-coded in real time
- **Percentage postfix** — Type `50%` to get `0.5`
- **Undo / redo** — Full native undo support in the editor
- **Pure Swift / SwiftUI** — No external dependencies

---

## Supported Syntax

### Basic Arithmetic
```
1 + 1        → 2
5 / 10       → 0.5
2^10         → 1024
32 % 7       → 4
50% * 12     → 6
```

### Variables
Variables are evaluated top-to-bottom and maintain their value until redefined.
```
a = 3        → 3
b = 5        → 5
a * b        → 15
a = 4        → 4
b * a        → 20
```

### Functions
Define functions with named parameters and a multi-line body.
```
func(a, b) {
    c = 2
    return a + b * c
}

func(5, 6)   → 17
```

Local variables and parameters are isolated from the sheet scope.

### Built-in Constants
| Name | Value |
|------|-------|
| `pi`, `π` | 3.14159... |
| `e` | 2.71828... |
| `phi`, `φ` | Golden ratio |
| `tau`, `τ` | 2π |
| `c` | Speed of light (m/s) |
| `G` | Gravitational constant |
| `h` | Planck constant |
| `k` | Boltzmann constant |
| `Na` | Avogadro's number |
| `R` | Ideal gas constant |
| `inf`, `infinity` | ∞ |
| `nan` | Not a number |

### Built-in Functions
| Function | Description |
|----------|-------------|
| `sqrt`, `cbrt` | Square / cube root |
| `abs` | Absolute value |
| `ceil`, `floor`, `round` | Rounding |
| `sin`, `cos`, `tan` | Trigonometric (radians) |
| `asin`, `acos`, `atan`, `atan2` | Inverse trig |
| `log`, `log2`, `log10` | Natural, base-2, base-10 log |
| `exp`, `pow` | Exponentiation |
| `min`, `max` | Minimum / maximum (2+ args) |
| `hypot` | Hypotenuse |

---

## Architecture

SparkCalc is built with a hybrid SwiftUI / AppKit architecture:

- **UI Layer** (`UI/`) — SwiftUI views wrapping a custom `NSTextView` via `NSViewRepresentable`
- **Syntax Highlighting** (`SyntaxHighlighting/`) — Incremental highlighter that only re-colors changed lines
- **Engine** (`Engine/`) — Recursive-descent expression parser with tokenization, evaluation, and function dispatch

The parser handles operator precedence, unary operators, postfix percentages, and function calls with arbitrary nesting.

---

## Build Requirements

- macOS 15+
- Xcode 16+
- Swift 6

---

## Roadmap

- [ ] Customizable color themes
- [ ] Multi-sheet support
- [ ] Export / import sheets

