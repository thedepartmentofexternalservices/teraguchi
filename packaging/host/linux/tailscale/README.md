# Guest policy examples

Offline P3 drafts only. Read the
[endpoint inventory and integration procedure](../../../../docs/development/teraguchi-guest-access-policy.md)
before adapting them.

- `guest-policy.example.json` is the guest-only grant. It is not a complete
  studio policy: preserve reviewed member/admin access and inspect overlapping
  grants and ACLs in the private full policy.
- `guest-tests.example.json` contains reserved example values. Substitute the
  actual accepted guest and shared workstation in a private copy before using
  Tailscale's validator. The local checker does not validate real Tailscale state.

Individual accepted machine shares control the reachable machines. The draft
limits their destination ports to TCP/UDP 28989. No script here applies policy,
invites guests, modifies host firewalls or enables SSH.

Offline guard:

```bash
bash scripts/test/check-guest-access-prep.sh "$PRIVATE_AUDIT/guest-access"
```

The checker requires populated reviewed submodules at their pinned gitlinks.
