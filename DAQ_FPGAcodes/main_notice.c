/* SPI Slave example, sender (uses SPI master driver)

 This example code is in the Public Domain (or CC0 licensed, at your option.)

 Unless required by applicable law or agreed to in writing, this
 software is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 CONDITIONS OF ANY KIND, either express or implied.
 */
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "esp_log.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_timer.h"
#include "nvs_flash.h"
#include "freertos/queue.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "freertos/semphr.h"
#include "freertos/queue.h"
#include "lwip/err.h"
#include "lwip/sys.h"
#include "lwip/netif.h"
#include "lwip/sockets.h"
#include "driver/spi_master.h"
#include "driver/gpio.h"
#define GPIO_HANDSHAKE 2
#define GPIO_OUTPUT 11

//WIFI 及 TCP参数
#define EXAMPLE_ESP_WIFI_SSID "iPhone"
#define EXAMPLE_ESP_WIFI_PASS "123456788"
char host_ip[] = "172.20.10.13";
int  port = 5001;

//SPI传输BUF尺寸定义
#define SPI_BUF_SIZE 1024

//WIFI连接最大重试次数
#define EXAMPLE_ESP_MAXIMUM_RETRY 10

static int s_retry_num = 0;

/* FreeRTOS event group to signal when we are connected*/
static EventGroupHandle_t s_wifi_event_group;
/* The event group allows multiple bits for each event, but we only care about two events:
 * - we are connected to the AP with an IP
 * - we failed to connect after the maximum amount of retries */
#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT BIT1

static char value[SPI_BUF_SIZE] = "12345678";

//static QueueHandle_t rdySem;

static TaskHandle_t gpio_set;
static TaskHandle_t ctrl;

static void IRAM_ATTR gpio_handshake_isr_handler(void *arg) {

	static uint32_t lasthandshaketime_us;
	uint32_t currtime_us = esp_timer_get_time();
	uint32_t diff = currtime_us - lasthandshaketime_us;
	if (diff < 10) {
		return; //ignore everything <1us after an earlier irq
	}
	lasthandshaketime_us = currtime_us;

	xTaskNotifyGive(ctrl); 
	//if (mustYield) {
		portYIELD_FROM_ISR();
	//}
}

static void event_handler(void *arg, esp_event_base_t event_base,int32_t event_id, void *event_data) {
	char *TAG = "wifi station";
	//第一步 esp_wifi_start() 产生WIFI_EVENT_STA_START事件
	if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
		//第二步连接WiFi
		esp_wifi_connect();
	}
	//第三步：第二步执行成功以后 产生 WIFI_EVENT_STA_CONNECTED 连接成功后开始获取IP
	//                否则产生 WIFI_EVENT_STA_DISCONNECTED 连接失败事件
	else if (event_base == WIFI_EVENT
			&& event_id == WIFI_EVENT_STA_DISCONNECTED) {
		if (s_retry_num < EXAMPLE_ESP_MAXIMUM_RETRY) {
			esp_wifi_connect();
			s_retry_num++;
			ESP_LOGI(TAG, "retry to connect to the AP");
		} else {
			//发送连接失败事件
			xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
		}
		ESP_LOGI(TAG, "connect to the AP fail");
	}
	//获取ip地址成功以后产生 IP_EVENT_STA_GOT_IP 事件 ，表示连接成功
	else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
		ip_event_got_ip_t *event = (ip_event_got_ip_t*) event_data;
		ESP_LOGI(TAG, "got ip:" IPSTR, IP2STR(&event->ip_info.ip));
		s_retry_num = 0;
		//发送连接成功事件
		xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
	}
}

void wifi_init_sta(void) {
	char *TAG = "wifi INIT";
	// 初始化事件组
	s_wifi_event_group = xEventGroupCreate();
//  初始化TCP/IP协议栈
	ESP_ERROR_CHECK(esp_netif_init());

	ESP_ERROR_CHECK(esp_event_loop_create_default());
	//  初始化WiFi底层驱动
	esp_netif_create_default_wifi_sta();

	wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
	ESP_ERROR_CHECK(esp_wifi_init(&cfg));

	esp_event_handler_instance_t instance_any_id;
	esp_event_handler_instance_t instance_got_ip;
	// 注册用户层的事件以及相关事件处理函数
	ESP_ERROR_CHECK(
			esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &event_handler, NULL, &instance_any_id));
	ESP_ERROR_CHECK(
			esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &event_handler, NULL, &instance_got_ip));

	wifi_config_t wifi_config = { 
        .sta = { 
            .ssid = EXAMPLE_ESP_WIFI_SSID,
			.password = EXAMPLE_ESP_WIFI_PASS,
			/* Setting a password implies station will connect to all security modes including WEP/WPA.
			 * However these modes are deprecated and not advisable to be used. Incase your Access point
			 * doesn't support WPA2, these mode can be enabled by commenting below line */
			.threshold.authmode = WIFI_AUTH_WPA2_PSK,

			.pmf_cfg = { 
                .capable = true, 
                .required = false 
            }, 
        }, 
    };
	// 配置好WiFi的工作模式 sta
	ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));

	ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
	// 启动WiFi
	ESP_ERROR_CHECK(esp_wifi_start());

	ESP_LOGI(TAG, "wifi_init_sta finished.");

	/* Waiting until either the connection is established (WIFI_CONNECTED_BIT) or connection failed for the maximum
	 * number of re-tries (WIFI_FAIL_BIT). The bits are set by event_handler() (see above) */
	//  等待网络连接结果
	EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
	WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
	pdFALSE,
	pdFALSE,
	portMAX_DELAY);

	/* xEventGroupWaitBits() returns the bits before the call returned, hence we can test which event actually
	 * happened. */
	if (bits & WIFI_CONNECTED_BIT) {
		ESP_LOGI(TAG, "connected to ap SSID:%s password:%s",
				EXAMPLE_ESP_WIFI_SSID, EXAMPLE_ESP_WIFI_PASS);
	} else if (bits & WIFI_FAIL_BIT) {
		ESP_LOGI(TAG, "Failed to connect to SSID:%s, password:%s",
				EXAMPLE_ESP_WIFI_SSID, EXAMPLE_ESP_WIFI_PASS);
	} else {
		ESP_LOGE(TAG, "UNEXPECTED EVENT");
	}

	/* The event will not be processed after unregister */
	// ESP_ERROR_CHECK(esp_event_handler_instance_unregister(IP_EVENT, IP_EVENT_STA_GOT_IP, instance_got_ip));
	// ESP_ERROR_CHECK(esp_event_handler_instance_unregister(WIFI_EVENT, ESP_EVENT_ANY_ID, instance_any_id));
	// vEventGroupDelete(s_wifi_event_group);
}


static void ctrl_task(void *pvParameters){
	gpio_config_t io_conf_handshake = {
			    .intr_type = GPIO_INTR_POSEDGE,     
                .mode = GPIO_MODE_INPUT,
			    .pull_up_en = 1,
			    .pin_bit_mask = (1 << GPIO_HANDSHAKE)
	};

	//Set up handshake line interrupt.
	gpio_config(&io_conf_handshake);
	gpio_install_isr_service(5);
	gpio_set_intr_type(GPIO_HANDSHAKE, GPIO_INTR_POSEDGE);
	gpio_isr_handler_add(GPIO_HANDSHAKE, gpio_handshake_isr_handler, NULL);

	while(1){

		ulTaskNotifyTake(ctrl,portMAX_DELAY);  //检查前面给出的Notify信号量

		xTaskNotify(gpio_set,1,eSetValueWithOverwrite); //然后再通过通知量把value的值传出去
	}
}

static void gpio_task(void *pvParameters){

	wifi_init_sta();
	char *TAG = "TCP_Client";
	int addr_family = 0;
	int ip_protocol = 0;

	struct sockaddr_in dest_addr;
	dest_addr.sin_addr.s_addr = inet_addr(host_ip);
	dest_addr.sin_family = AF_INET;
	dest_addr.sin_port = htons(port);
	addr_family = AF_INET;
	ip_protocol = IPPROTO_IP;

	while (1) {
		int sock = socket(addr_family, SOCK_STREAM, ip_protocol);
		if (sock < 0) {
			ESP_LOGE(TAG, "Unable to create socket: errno %d", errno);
		}

		int err = connect(sock, (struct sockaddr*) &dest_addr,
				sizeof(struct sockaddr_in6));
		if (err != 0) {
			ESP_LOGE(TAG, "Socket unable to connect: errno %d", errno);
		}
		ESP_LOGI(TAG, "TCP Successfully connected");

	    static uint32_t flag;

	    while(1){

		    xTaskNotifyWait(0,1,&flag,portMAX_DELAY);

		    if(flag){
			    send(sock, value, strlen(value), 0);
		    }
	    }
    }
}

void init_nvs() {
	esp_err_t ret = nvs_flash_init();
	if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
		ESP_ERROR_CHECK(nvs_flash_erase());
		ret = nvs_flash_init();
	}
	ESP_ERROR_CHECK(ret);
}

//Main application
void app_main(void) {

	init_nvs();

	xTaskCreatePinnedToCore(ctrl_task, "ctrl_task", 8192, NULL, 1, &ctrl,0);

	xTaskCreatePinnedToCore(gpio_task, "gpio_task", 8192, NULL, 1, &gpio_set,1);
	//解决assert failed: xQueueGiveFromISR queue.c:1224 (pxQueue)问题的方法是修改任务句柄&gpio_set和任务优先级

}
