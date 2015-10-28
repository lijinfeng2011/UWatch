-module(watch_admin).
-compile(export_all).

addadmin(User) -> watch_db:add_admin(User).
getadmin(User) -> watch_db:get_admin(User).
deladmin(User) -> watch_db:del_admin(User).

listadmin() -> watch_db:list_admin().
