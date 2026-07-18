# FREIRAUM Trust Operations

The trust module provides:

- parking-space verification requests,
- user support requests linked to bookings or listings,
- an admin moderation queue,
- a notification outbox for future email delivery,
- draft privacy, terms, and imprint screens.

## Admin access

Set one or more comma-separated account emails on the server:

```env
ADMIN_EMAILS=admin@example.com,operations@example.com
TRUST_SUPPORT_EMAIL=support@example.com
```

Only authenticated accounts whose normalized email is listed in `ADMIN_EMAILS`
can use `/api/admin/trust/*` and open `/admin/trust` successfully.

## Moderation flow

1. A host submits a verification request for an owned parking space.
2. An admin approves or rejects it.
3. Approval updates the public `is_verified` state of the listing.
4. Users and hosts can create support requests linked to their bookings or listings.
5. Admins can move requests through `open`, `triaged`, `resolved`, or `dismissed`.
6. Every submission and review writes a deduplicated notification record to the outbox.

## Before public release

- Configure real admin and support email addresses.
- Connect the notification outbox to the selected email provider.
- Replace the legal MVP drafts with reviewed company-specific documents.
- Add the complete legal entity, address, register, tax, and contact details.
- Test verification and support workflows with separate user, host, and admin accounts.
