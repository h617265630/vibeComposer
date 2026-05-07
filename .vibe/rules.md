# Harness Rules

## Editing Rules
- 新增功能必须更新 track.md。
- 不允许删除已有 API。
- 不允许直接修改数据库字段，必须写 migration。
- 新页面必须登记到 Frontend Pages。
- 新 API 必须登记到 Backend API。
- 新表必须登记到 Database。
- 新 AI Logic 必须登记到 AI Logic。

## Quality Rules
- 每次改动都要做最小化验证（构建、类型检查或关键测试）。
- 输出必须标注影响范围与回滚点。
- 遇到不确定上下文时先记录假设，再执行。