import 'package:flutter/material.dart';
import 'chat_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pesan"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundImage:
                  NetworkImage("https://i.imgur.com/BoN9kdC.png"),
            ),
            title: const Text(
              "Maggy Lee",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              "Kalau Rp350.000 bagaimana kak?",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  "1 menit",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SizedBox(height: 4),
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text(
                    "1",
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatPage(
                    productId: "prod_001",
                    productName: "Vintage Levi’s 517 Faded Black",
                    offerPrice: "200000",
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
