# ThriftHeads launch checklist

The code is wired together, but these external values cannot safely be pre-filled:

- Supabase project URL and anon key
- PayMongo secret key
- PayMongo webhook signing secret/configuration
- Supabase service-role key for Edge Functions
- Production domain
- Legal/business policy text
- Courier integration/actual shipping rates

## Verify before accepting real money

1. Run the SQL migration on the production Supabase project.
2. Configure Auth redirect URLs.
3. Set Edge Function secrets.
4. Deploy Edge Functions.
5. Configure PayMongo webhook to point to `paymongo-webhook`.
6. Confirm the webhook signature verification matches the exact current PayMongo dashboard/API specification for your account before switching to live mode.
7. Test a full sandbox payment.
8. Test duplicate webhook delivery.
9. Test two simultaneous purchases of the same one-of-one product.
10. Test cancellation/refund behavior.
11. Configure real shipping fees/courier workflow.
12. Replace placeholder legal pages.
13. Promote the intended admin account.
14. Enable production domain/HTTPS.
