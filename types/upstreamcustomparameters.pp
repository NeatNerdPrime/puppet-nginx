# @summary Type Alias for Nginx::UpstreamCustomParameters
type Nginx::UpstreamCustomParameters = Hash[String[1],
  Variant[
    String[1],
    Integer,
    Array[
      Variant[
        String[1],
        Integer
      ]
    ],
    Hash[String[1],
      Variant[
        String[1],
        Integer,
        Array[
          Variant[
            String[1],
            Integer,
          ]
        ]
      ]
    ]
  ]
]
