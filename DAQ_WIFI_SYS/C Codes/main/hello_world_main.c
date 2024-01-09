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
#include "esp32s3/rom/ets_sys.h"

/*FPGA-ESP32 SPI接口*/
#define GPIO_HANDSHAKE 14
#define GPIO_MOSI 11
#define GPIO_MISO 13
#define GPIO_SCLK 12
#define GPIO_CS 10
#define GPIO_SIGNAL 36
#define SENDER_HOST SPI2_HOST	//IO MUX Fast SPI

//WIFI及TCP参数
#define EXAMPLE_ESP_WIFI_SSID "HUAWEI_B535_D41B"
#define EXAMPLE_ESP_WIFI_PASS "Qing0808"
char host_ip[] = "192.168.8.20";
int  port = 5001;
/*
#define EXAMPLE_ESP_WIFI_SSID "FAST_1660"
#define EXAMPLE_ESP_WIFI_PASS "cuijin417"
char host_ip[] = "192.168.1.101";
int  port = 5001;
*/
//SPI传输BUF尺寸定义
#define SPI_RECV_BUF_SIZE 11555 //100000
#define SPI_SEND_BUF_SIZE 11552

//WiFi传输BUF尺寸定义
#define WIFI_SEND_BUF_SIZE 11552
//#define WIFI_TCP_MSS 11520
//#define WIFI_SEND_RES 256

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


static char sendbuf[SPI_SEND_BUF_SIZE] = {0};
static char recvbuf[SPI_RECV_BUF_SIZE] = {0};
//static char recvbuf1[SPI_RECV_BUF_SIZE] = {0};
//static char recvbuf2[SPI_RECV_BUF_SIZE] = {0};

//指向SPI传输缓冲区和WiFi发送缓冲区的指针
//static char *spi_recv_buffer;
//static char *wifi_sendbuf;


//static char *wifi_sendbuf;

//分配片外PSRAM
//heap_caps_malloc(WIFI_BUF_SIZE, MALLOC_CAP_SPIRAM);

static char wifi_sendbuf[WIFI_SEND_BUF_SIZE] = {0};
//char *wifi_sendbuf = (char*)heap_caps_malloc(WIFI_BUF_SIZE, MALLOC_CAP_SPIRAM);

//static const char *TAG = "ERROR";

static TaskHandle_t spi;	//主SPI传输任务句柄

static TaskHandle_t wifisend;


static void IRAM_ATTR gpio_handshake_isr_handler(void *arg) {

	static uint32_t lasthandshaketime_us;
	uint32_t currtime_us = esp_timer_get_time();
	uint32_t diff = currtime_us - lasthandshaketime_us;
	if (diff < 10) {
		return; //ignore everything <1us after an earlier irq
	}
	lasthandshaketime_us = currtime_us;

	BaseType_t xHigherPriorityTaskWoken;
	xHigherPriorityTaskWoken = pdFALSE;
	//xTaskNotifyGive(spi);
	vTaskNotifyGiveFromISR(spi, &xHigherPriorityTaskWoken);

	portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
	//portYIELD_FROM_ISR();

}

static void event_handler(void *arg, esp_event_base_t event_base,int32_t event_id, void *event_data) {
	char *TAG = "wifi station";

	if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {

		esp_wifi_connect();
	}

	else if (event_base == WIFI_EVENT
			&& event_id == WIFI_EVENT_STA_DISCONNECTED) {
		if (s_retry_num < EXAMPLE_ESP_MAXIMUM_RETRY) {
			esp_wifi_connect();
			s_retry_num++;
			ESP_LOGI(TAG, "retry to connect to the AP");
		} else {

			xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
		}
		ESP_LOGI(TAG, "connect to the AP fail");
	}

	else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
		ip_event_got_ip_t *event = (ip_event_got_ip_t*) event_data;
		ESP_LOGI(TAG, "got ip:" IPSTR, IP2STR(&event->ip_info.ip));
		s_retry_num = 0;

		xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
	}
}

void wifi_init_sta(void) {
	char *TAG = "wifi INIT";

	s_wifi_event_group = xEventGroupCreate();

	ESP_ERROR_CHECK(esp_netif_init());

	ESP_ERROR_CHECK(esp_event_loop_create_default());

	esp_netif_create_default_wifi_sta();

	wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
	ESP_ERROR_CHECK(esp_wifi_init(&cfg));

	esp_event_handler_instance_t instance_any_id;
	esp_event_handler_instance_t instance_got_ip;

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

	ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));

	ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));

	ESP_ERROR_CHECK(esp_wifi_start());

	ESP_LOGI(TAG, "wifi_init_sta finished.");

	/* Waiting until either the connection is established (WIFI_CONNECTED_BIT) or connection failed for the maximum
	 * number of re-tries (WIFI_FAIL_BIT). The bits are set by event_handler() (see above) */
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

static void spi_task(void *pvParameters){
	//printf("Task performing");

	//初始化握手信号(FPGA->ESP32的触发信号)
	gpio_config_t io_conf_handshake = {
		.intr_type = GPIO_INTR_POSEDGE,
		.mode = GPIO_MODE_INPUT,
		.pull_down_en = 1,
		.pin_bit_mask = (1 << GPIO_HANDSHAKE)
	};
	//printf("About to config GPIO");
	//Set up handshake line interrupt.
	gpio_config(&io_conf_handshake);
	//printf("Finished GPIO config");
	gpio_install_isr_service(2);
	gpio_set_intr_type(GPIO_HANDSHAKE, GPIO_INTR_POSEDGE);
	gpio_isr_handler_add(GPIO_HANDSHAKE, gpio_handshake_isr_handler, NULL);

	esp_err_t ret;
	spi_device_handle_t handle;

	//Configuration for the SPI bus
	spi_bus_config_t buscfg = {
        .mosi_io_num = GPIO_MOSI,
        .miso_io_num = GPIO_MISO,
        .sclk_io_num = GPIO_SCLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
		.max_transfer_sz = 100000
    };

	//Configuration for the SPI device on the other side of the bus
	spi_device_interface_config_t devcfg = {
        .command_bits = 0,
        .address_bits = 0,
        .dummy_bits = 0,
        .clock_speed_hz = 30000000,
		.input_delay_ns = 0,
        .duty_cycle_pos = 128,        //50% duty cycle
		.mode = 1,
        .spics_io_num = GPIO_CS,
        .cs_ena_posttrans = 1, //Keep the CS low 3 cycles after transaction, to stop slave from missing the last bit when CS has less propagation delay than CLK
		.queue_size = 3
    };

	spi_transaction_t t;
	//Initialize the SPI bus and add the
	//device we want to send stuff to.
	ret = spi_bus_initialize(SENDER_HOST, &buscfg, SPI_DMA_CH_AUTO);
	assert(ret==ESP_OK);
	ret = spi_bus_add_device(SENDER_HOST, &devcfg, &handle);
	assert(ret==ESP_OK);

	//int buffer_select;
	int spi_notify_value;

	while(1){

		/*if(buffer_select==0){
			spi_recv_buffer = recvbuf1;
		}else{
			spi_recv_buffer = recvbuf2;
		}*/
		t.length = sizeof(recvbuf) * 8;
		t.rx_buffer = recvbuf;
		//t.rx_buffer = spi_recv_buffer;
		t.tx_buffer = sendbuf;

		ulTaskNotifyTake(spi,portMAX_DELAY);
		//spi_notify_value = ulTaskNotifyTake(pdFALSE,portMAX_DELAY);

		//if(spi_notify_value!=0){

			ret = spi_device_transmit(handle, &t);
			memcpy(wifi_sendbuf, recvbuf, WIFI_SEND_BUF_SIZE);	//把SPI接收缓冲区的数据打入WiFi发送缓冲区
			//printf("SPI Received Data%s\n",wifi_sendbuf);
			//vTaskDelay(1 / portTICK_PERIOD_MS);
			//wifi_sendbuf = spi_recv_buffer;	//WiFi发送区设置为刚接收完的buffer
			xTaskNotifyGive(wifisend);
			//buffer_select = !buffer_select;	   //对buffer_select取反，切换接收buffer

		//}

		//下面这个Notify是必选项，原因是控制指令的接收也需要WiFi来传输

		//xTaskNotify(wifisend,1,eSetValueWithOverwrite);
		//vTaskDelay(1 / portTICK_PERIOD_MS);
	}
}

static void wifisend_task(void *pvParameters){
	//WiFi任务
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
		//printf("wifisend_task in performating.");
		int sock = socket(addr_family, SOCK_STREAM, ip_protocol);
		if (sock < 0) {
			ESP_LOGE(TAG, "Unable to create socket: errno %d", errno);
		}
		//ESP_LOGI(TAG, "Socket created, connecting to %s:%d", host_ip, port);
		int err = connect(sock, (struct sockaddr*) &dest_addr, sizeof(struct sockaddr_in6));
		if (err != 0) {
			ESP_LOGE(TAG, "Socket unable to connect: errno %d", errno);
		}
		ESP_LOGI(TAG, "TCP Successfully connected");
		printf("Outer loop performing");
		//static uint32_t flag;
		static int NotifyValue;
		//static int send_cnt;
		//static char *ptr;
		while(1){

			//flag = 0;
			//xTaskNotifyWait(0,1,&flag,portMAX_DELAY);
			//ulTaskNotifyTake(wifisend,portMAX_DELAY);
			NotifyValue = ulTaskNotifyTake(pdFALSE,portMAX_DELAY);

			if(NotifyValue!=0){
				//vTaskDelay(1 / portTICK_PERIOD_MS);
				printf("NotifyValue:%d\n",NotifyValue);
				/*send_cnt = 0;
				//WiFi分片发送
				while(send_cnt!=1){
					ptr = wifi_sendbuf + send_cnt*WIFI_TCP_MSS;
					send(sock, ptr, WIFI_TCP_MSS, 0);  
					send_cnt++;
					//printf("Send:%d\n",send_cnt);
				}*/
				send(sock, wifi_sendbuf, sizeof(wifi_sendbuf), 0);  //recvbuf就是接收数据存放的地址
			//vTaskDelay(1 / portTICK_PERIOD_MS);
			}
		}
		//vTaskDelete(NULL);
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
/*
    int cnt=0;
    while(cnt!=WIFI_SEND_BUF_SIZE){
        wifi_sendbuf[cnt]=1;
        cnt++;
    }
*/
	init_nvs();

	//wifi_sendbuf = (char*)heap_caps_malloc(WIFI_BUF_SIZE, MALLOC_CAP_SPIRAM);

	xTaskCreatePinnedToCore(spi_task, "spi_task", 10500, NULL, 3, &spi,0);

	xTaskCreatePinnedToCore(wifisend_task, "wifisend_task", 10500, NULL, 3, &wifisend,1);

	//printf("Finished shadualing");
}
