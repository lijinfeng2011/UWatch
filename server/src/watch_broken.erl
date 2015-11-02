-module(watch_broken).
-compile(export_all).

addbroken(User) -> watch_db:add_broken(User).
delbroken(User) -> watch_db:del_broken(User).

listbroken() -> watch_db:list_broken().
