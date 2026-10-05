-- PostgREST caches the catalog, so a newly created function 404s on /rest/v1/rpc
-- until the cache is refreshed. This tells it to reload.
notify pgrst, 'reload schema';
