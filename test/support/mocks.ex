alias LastfmArchive.Behaviour

Hammox.defmock(LastfmArchive.LastfmClientMock, for: Behaviour.LastfmClient)
Hammox.defmock(LastfmArchive.FileArchiveMock, for: Behaviour.Archive)
Hammox.defmock(LastfmArchive.FileIOMock, for: Behaviour.FileIO)
Hammox.defmock(LastfmArchive.PathIOMock, for: Behaviour.PathIO)
Hammox.defmock(LastfmArchive.CacheMock, for: LastfmArchive.Cache)
