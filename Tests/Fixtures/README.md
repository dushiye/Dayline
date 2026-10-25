# 兼容性测试夹具

- `v1-backup.json`：schemaVersion=1 的旧版 JSON，用于验证 v1.1 可以恢复原有领域、目标、任务和重复关联。旧备份没有 Ideas 或计划历史；恢复时完整替换现有数据，并为导入任务建立当下观察基线。
- `v1.store`：由真实 v1 模型生成的 SQLite 数据库，用于验证新增 Idea / PlanningEventEntity 后的迁移。原有模型结构保持不变。伴随的 `v1.store-shm` 是 SQLite 运行时侧文件，不能当作独立数据备份。

运行 `DEVELOPER_DIR=/Library/Developer/CommandLineTools scripts/test-v11.sh`。测试通过 SQLite 在线备份复制夹具到隔离临时目录后再迁移，不操作个人正式数据库；覆盖冷数据库和仍有活动 WAL 的安全快照、迁移后继续编辑、v1 / v2 JSON 往返及历史身份保留。升级前快照包含已提交 WAL 内容并独立落盘，不能用只复制主 SQLite 文件代替。

v1.1 集成已通过 12/12 检查（含上海/洛杉矶运行时时区切换的历史归属）。计划引擎另由 `scripts/test-planning.sh` 生成合成 14 日记录验证，不将虚构历史写入真实用户数据。导出样本位于 `output/v1.1-exports/`，不属于迁移夹具。完整执行状态见 [QA 记录](../../Documentation/QA.md)。
