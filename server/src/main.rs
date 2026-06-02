use axum::{
    Json, Router,
    extract::ws::{Message, WebSocket, WebSocketUpgrade},
    http::header,
    response::IntoResponse,
    routing::get,
};
use futures_util::StreamExt;
use local_ip_address::local_ip;
use serde::Serialize;
use std::{
    net::SocketAddr,
    sync::atomic::{AtomicUsize, Ordering},
};
use tokio::net::TcpListener;

const HOST: &str = "0.0.0.0";
const PORT: u16 = 9600;
static NEXT_CONNECTION_ID: AtomicUsize = AtomicUsize::new(1);

#[derive(Serialize)]
struct VersionResponse {
    name: &'static str,
    version: &'static str,
}

#[derive(Serialize)]
struct ConversationResponse {
    title: &'static str,
    #[serde(rename = "lastMsg")]
    last_msg: &'static str,
    time: &'static str,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let app = Router::new()
        .route("/v", get(version))
        .route("/conversation", get(conversations))
        .route("/ws", get(websocket_handler));
    let addr: SocketAddr = format!("{HOST}:{PORT}").parse()?;
    let listener = TcpListener::bind(addr).await?;

    print_access_urls(PORT);

    axum::serve(listener, app).await?;
    Ok(())
}

async fn version() -> impl IntoResponse {
    utf8_json(Json(VersionResponse {
        name: env!("CARGO_PKG_NAME"),
        version: env!("CARGO_PKG_VERSION"),
    }))
}

async fn conversations() -> impl IntoResponse {
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

async fn websocket_handler(websocket: WebSocketUpgrade) -> impl IntoResponse {
    let connection_id = NEXT_CONNECTION_ID.fetch_add(1, Ordering::Relaxed);

    websocket.on_upgrade(move |socket| handle_websocket(socket, connection_id))
}

async fn handle_websocket(mut socket: WebSocket, connection_id: usize) {
    println!("ws connected: connection_id={connection_id}");

    if let Err(error) = socket
        .send(Message::Text("welcome to flash_im websocket".into()))
        .await
    {
        println!("ws send failed on connect: connection_id={connection_id}, error={error}");
        return;
    }

    while let Some(result) = socket.next().await {
        match result {
            Ok(Message::Text(text)) => {
                let reply = format!("echo: {text}");
                if let Err(error) = socket.send(Message::Text(reply.into())).await {
                    println!("ws send failed: connection_id={connection_id}, error={error}");
                    break;
                }
            }
            Ok(Message::Close(_)) => break,
            Ok(_) => {}
            Err(error) => {
                println!("ws receive failed: connection_id={connection_id}, error={error}");
                break;
            }
        }
    }

    println!("ws disconnected: connection_id={connection_id}");
}

fn utf8_json<T>(json: Json<T>) -> impl IntoResponse
where
    Json<T>: IntoResponse,
{
    (
        [(header::CONTENT_TYPE, "application/json; charset=utf-8")],
        json,
    )
}

fn print_access_urls(port: u16) {
    println!("server started");
    println!("local:   http://127.0.0.1:{port}/v");

    match local_ip() {
        Ok(ip) => println!("network: http://{ip}:{port}/v"),
        Err(error) => println!("network: unable to detect local ip: {error}"),
    }
}
