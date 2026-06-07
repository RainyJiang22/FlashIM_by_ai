use axum::{Json, response::IntoResponse};

use crate::{models::chat::ConversationResponse, response::utf8_json};

pub async fn conversations() -> impl IntoResponse {
    utf8_json(Json(vec![
        ConversationResponse {
            title: "产品讨论群",
            last_msg: "今晚先把登录流程对齐一下。",
            time: "09:12",
        },
        ConversationResponse {
            title: "Rust 后端小组",
            last_msg: "Axum 的路由已经跑通了。",
            time: "09:25",
        },
        ConversationResponse {
            title: "Flutter 客户端",
            last_msg: "会话列表页面我来接接口。",
            time: "09:41",
        },
        ConversationResponse {
            title: "设计评审",
            last_msg: "头像和气泡样式需要再收敛一点。",
            time: "10:03",
        },
        ConversationResponse {
            title: "测试反馈",
            last_msg: "弱网重连的用例已经补上。",
            time: "10:18",
        },
        ConversationResponse {
            title: "运维通知",
            last_msg: "今晚 23 点有一次数据库备份演练。",
            time: "10:36",
        },
        ConversationResponse {
            title: "AI 助手",
            last_msg: "已生成今日待办摘要。",
            time: "10:52",
        },
        ConversationResponse {
            title: "张雨",
            last_msg: "接口返回字段我看到了，没问题。",
            time: "11:06",
        },
        ConversationResponse {
            title: "李明",
            last_msg: "下午三点同步一下进度。",
            time: "11:20",
        },
        ConversationResponse {
            title: "王晓",
            last_msg: "我把截图发到群里了。",
            time: "11:45",
        },
        ConversationResponse {
            title: "项目周会",
            last_msg: "本周重点是消息链路和会话列表。",
            time: "12:10",
        },
        ConversationResponse {
            title: "后端告警",
            last_msg: "本地服务已恢复正常。",
            time: "12:28",
        },
        ConversationResponse {
            title: "接口联调",
            last_msg: "先用假数据把 UI 跑起来。",
            time: "13:02",
        },
        ConversationResponse {
            title: "素材同步",
            last_msg: "默认头像资源已经上传。",
            time: "13:17",
        },
        ConversationResponse {
            title: "安全审核",
            last_msg: "后续登录态要加过期校验。",
            time: "13:40",
        },
        ConversationResponse {
            title: "群聊 Demo",
            last_msg: "20 条模拟会话足够先展示。",
            time: "14:05",
        },
        ConversationResponse {
            title: "小程序适配",
            last_msg: "先不处理，等核心链路稳定。",
            time: "14:22",
        },
        ConversationResponse {
            title: "数据建模",
            last_msg: "conversation 表需要单独设计。",
            time: "14:48",
        },
        ConversationResponse {
            title: "发布准备",
            last_msg: "提交前跑一下 clippy。",
            time: "15:11",
        },
        ConversationResponse {
            title: "系统消息",
            last_msg: "欢迎使用 flash_im。",
            time: "15:30",
        },
    ]))
}
