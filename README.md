# maip.nvim

MAIP plugin for Neovim. Machine identity, cryptographic receipts, trust scores.

## Install (lazy.nvim)

```lua
{ "truthlocks/maip.nvim", config = true }
```

## Get Started

```vim
:TruthlocksRegister dev@example.com
:TruthlocksProtect
```

No website needed. Free: 100 protections/month.

## Features

- :TruthlocksRegister - instant signup from Neovim
- :TruthlocksProtect - protect current buffer
- :TruthlocksVerify - verify attestation
- 10 algorithms (Ed25519, ES256, ES384, ES512, RS256-PS512)
- Telescope integration for browsing receipts

## Config

```lua
require("maip").setup({
  algorithm = "Ed25519",
  auto_receipt_on_save = false,
  auto_receipt_on_commit = true,
})
```

## Docs

https://docs.truthlocks.com

## License

MIT
