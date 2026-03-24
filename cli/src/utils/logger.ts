import pc from "picocolors";

export const log = {
  info: (msg: string) => console.log(pc.blue("::"), msg),
  success: (msg: string) => console.log(pc.green("::"), msg),
  warn: (msg: string) => console.log(pc.yellow("::"), pc.yellow(msg)),
  error: (msg: string) => console.error(pc.red("::"), pc.red(msg)),
  step: (n: number, total: number, msg: string) =>
    console.log(pc.dim(`[${n}/${total}]`), msg),
  pass: (msg: string) => console.log(pc.green("  PASS"), msg),
  fail: (msg: string) => console.log(pc.red("  FAIL"), msg),
};
