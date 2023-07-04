alias LastfmArchive.Behaviour

Hammox.defmock(LastfmArchive.Archive.FileArchiveMock, for: Behaviour.Archive)
Hammox.defmock(LastfmArchive.Archive.DerivedArchiveMock, for: Behaviour.Archive)

Hammox.defmock(LastfmArchive.CacheMock, for: LastfmArchive.Cache)
Hammox.defmock(LastfmArchive.FileIOMock, for: Behaviour.FileIO)
Hammox.defmock(LastfmArchive.LastfmClientMock, for: Behaviour.LastfmClient)
Hammox.defmock(LastfmArchive.PathIOMock, for: Behaviour.PathIO)

Hammox.defmock(Explorer.DataFrameMock, for: Behaviour.DataFrameIo)
