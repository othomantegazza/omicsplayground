renv::install(
    c(
        'JohnCoene/firebase@6132b6f7f8bc5ec71536f0fde00de0d4268bf8bf',
        'dreamRs/particlesjs',
        'kasperdanielhansen/Rgraphviz',
    ),  
)

renv::install('pathview', repos = BiocManager::repositories())
