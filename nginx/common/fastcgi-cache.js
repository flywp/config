/**
 * Pages are stored in the FastCGI cache with the Set-Cookie headers of the visitor
 * who filled the cache. Those cookies go only to that visitor: a page served from
 * the cache is sent without them.
 */
function stripCachedCookies(r) {
    if (!['', 'MISS', 'BYPASS', 'EXPIRED'].includes(r.variables.upstream_cache_status || '')) {
        delete r.headersOut['Set-Cookie'];
    }
}

export default { stripCachedCookies };
