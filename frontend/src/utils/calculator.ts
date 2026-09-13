export type AngleMode = 'deg' | 'rad'

const FUNCTIONS = new Set(['sin', 'cos', 'tan', 'log', 'ln', 'sqrt'])

type Token =
  | { type: 'num'; value: number }
  | { type: 'op'; value: '+' | '-' | '*' | '/' | '^' }
  | { type: 'fn'; value: string }
  | { type: 'lp' }
  | { type: 'rp' }
  | { type: 'postfix'; value: '!' | '%' }

export function formatCalcNumber(value: number): string {
  if (!Number.isFinite(value)) throw new Error('Invalid result')
  if (value === 0 || Object.is(value, -0)) return '0'

  const abs = Math.abs(value)
  if (abs >= 1e12 || abs < 1e-9) {
    return value.toExponential(6).replace(/\.?0+e/, 'e').replace('e+', 'e')
  }

  return String(Number(value.toPrecision(12)))
}

export function evaluateExpression(input: string, angle: AngleMode = 'deg'): number {
  const tokens = tokenize(input)
  if (!tokens.length) throw new Error('Empty expression')

  const parser = new Parser(tokens, angle)
  const value = parser.parse()
  if (!Number.isFinite(value)) throw new Error('Invalid result')
  return value
}

function tokenize(input: string): Token[] {
  const src = input.replace(/\s+/g, '').replace(/×/g, '*').replace(/÷/g, '/').replace(/−/g, '-')
  const tokens: Token[] = []
  let index = 0

  while (index < src.length) {
    const char = src[index]

    if (/[0-9.]/.test(char)) {
      let end = index + 1
      while (end < src.length && /[0-9.]/.test(src[end])) end += 1
      const value = Number(src.slice(index, end))
      if (!Number.isFinite(value)) throw new Error('Invalid number')
      tokens.push({ type: 'num', value })
      index = end
      continue
    }

    if (/[a-z]/i.test(char)) {
      let end = index + 1
      while (end < src.length && /[a-z]/i.test(src[end])) end += 1
      const name = src.slice(index, end).toLowerCase()
      if (name === 'pi') tokens.push({ type: 'num', value: Math.PI })
      else if (name === 'e') tokens.push({ type: 'num', value: Math.E })
      else if (FUNCTIONS.has(name)) tokens.push({ type: 'fn', value: name })
      else throw new Error('Unknown function')
      index = end
      continue
    }

    if (char === '(') tokens.push({ type: 'lp' })
    else if (char === ')') tokens.push({ type: 'rp' })
    else if (char === '!' || char === '%') tokens.push({ type: 'postfix', value: char })
    else if (char === '+' || char === '-' || char === '*' || char === '/' || char === '^') {
      tokens.push({ type: 'op', value: char })
    } else {
      throw new Error('Unexpected token')
    }
    index += 1
  }

  return tokens
}

class Parser {
  private index = 0

  constructor(
    private readonly tokens: Token[],
    private readonly angle: AngleMode,
  ) {}

  parse(): number {
    const value = this.expression()
    if (this.index < this.tokens.length) throw new Error('Unexpected token')
    return value
  }

  private peek(): Token | undefined {
    return this.tokens[this.index]
  }

  private eat(): Token {
    const token = this.tokens[this.index]
    if (!token) throw new Error('Unexpected end')
    this.index += 1
    return token
  }

  private expression(): number {
    let left = this.term()
    while (this.peek()?.type === 'op' && (this.peek()?.value === '+' || this.peek()?.value === '-')) {
      const op = this.eat().value
      if ((op === '+' || op === '-') && this.peek()?.type === 'num' && this.tokens[this.index + 1]?.type === 'postfix' && this.tokens[this.index + 1]?.value === '%') {
        const percent = (this.eat() as { type: 'num'; value: number }).value
        this.eat()
        const delta = left * (percent / 100)
        left = op === '+' ? left + delta : left - delta
        continue
      }
      const right = this.term()
      left = op === '+' ? left + right : left - right
    }
    return left
  }

  private term(): number {
    let left = this.power()
    while (this.peek()?.type === 'op' && (this.peek()?.value === '*' || this.peek()?.value === '/')) {
      const op = this.eat().value
      const right = this.power()
      if (op === '/' && right === 0) throw new Error('Division by zero')
      left = op === '*' ? left * right : left / right
    }
    return left
  }

  private power(): number {
    let left = this.unary()
    if (this.peek()?.type === 'op' && this.peek()?.value === '^') {
      this.eat()
      left **= this.power()
    }
    return left
  }

  private unary(): number {
    if (this.peek()?.type === 'op' && this.peek()?.value === '-') {
      this.eat()
      return -this.unary()
    }
    if (this.peek()?.type === 'op' && this.peek()?.value === '+') {
      this.eat()
      return this.unary()
    }
    return this.postfix()
  }

  private postfix(): number {
    let value = this.primary()
    while (this.peek()?.type === 'postfix') {
      const op = this.eat().value
      value = op === '%' ? value / 100 : factorial(value)
    }
    return value
  }

  private primary(): number {
    const token = this.peek()
    if (!token) throw new Error('Unexpected end')

    if (token.type === 'num') {
      this.eat()
      return token.value
    }

    if (token.type === 'fn') {
      this.eat()
      this.expect('lp')
      const arg = this.expression()
      this.expect('rp')
      return applyFunction(token.value, arg, this.angle)
    }

    if (token.type === 'lp') {
      this.eat()
      const value = this.expression()
      this.expect('rp')
      return value
    }

    throw new Error('Unexpected token')
  }

  private expect(type: Token['type']) {
    if (this.peek()?.type !== type) throw new Error('Unexpected token')
    this.eat()
  }
}

function applyFunction(name: string, arg: number, angle: AngleMode): number {
  const trig = angle === 'deg' ? (arg * Math.PI) / 180 : arg
  switch (name) {
    case 'sin':
      return Math.sin(trig)
    case 'cos':
      return Math.cos(trig)
    case 'tan':
      return Math.tan(trig)
    case 'log':
      if (arg <= 0) throw new Error('Invalid log')
      return Math.log10(arg)
    case 'ln':
      if (arg <= 0) throw new Error('Invalid ln')
      return Math.log(arg)
    case 'sqrt':
      if (arg < 0) throw new Error('Invalid sqrt')
      return Math.sqrt(arg)
    default:
      throw new Error('Unknown function')
  }
}

function factorial(value: number): number {
  if (!Number.isInteger(value) || value < 0 || value > 170) throw new Error('Invalid factorial')
  let result = 1
  for (let n = 2; n <= value; n += 1) result *= n
  return result
}
