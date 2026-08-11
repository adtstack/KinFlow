-- KinFlow WP07-02B separates Owner-authorized household archives from the
-- existing personal export request type. Keeping the enum change in its own
-- migration makes the new value safe to use in the following transaction.

alter type public.privacy_request_type add value if not exists 'export_household';
