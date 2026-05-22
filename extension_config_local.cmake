duckdb_extension_load(httpfs
    LOAD_TESTS
    GIT_URL https://github.com/duckdb/duckdb-httpfs
    GIT_TAG 354d3f436a33f80f03a74419e76eb59459e19168
    INCLUDE_DIR extension/httpfs/include
)

duckdb_extension_load(postgres_scanner
            DONT_LINK
            GIT_URL https://github.com/duckdb/duckdb-postgres
            GIT_TAG 6dabd956065e59b24d615fe03bab84d677fca6df
)

duckdb_extension_load(excel
    LOAD_TESTS
    GIT_URL https://github.com/duckdb/duckdb-excel
    GIT_TAG 27ebb61fefda2e29bf649f4348dff233880cf582
    INCLUDE_DIR src/excel/include
)


duckdb_extension_load(nanoarrow
    LOAD_TESTS
    LINKED_LIBS "../../_deps/nanoarrow-build/lib*.a"
    GIT_URL https://github.com/paleolimbot/duckdb-nanoarrow
    GIT_TAG 0201908c2163218aba0b8eb95fca753ab3ee3868
    INCLUDE_DIR src/include
)
