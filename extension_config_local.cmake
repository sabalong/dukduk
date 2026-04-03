duckdb_extension_load(postgres_scanner
            DONT_LINK
            GIT_URL https://github.com/duckdb/duckdb-postgres
            GIT_TAG c3024b5c8570695dc73422066fcd221ed64761de
)

duckdb_extension_load(excel
    LOAD_TESTS
    GIT_URL https://github.com/duckdb/duckdb-excel
    GIT_TAG 0f1df3b14ad6458b90b52c5f625b409a44648c05
    INCLUDE_DIR src/excel/include
)


duckdb_extension_load(arrow
    LOAD_TESTS
    LINKED_LIBS
    GIT_URL https://github.com/duckdb/arrow
    GIT_TAG aa244456bbbb805a9837cdd405d6f022d9e8d9ef
)