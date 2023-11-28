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
#include "esp_pm.h"

#define GPIO_HANDSHAKE 2
#define GPIO_MOSI 13
#define GPIO_MISO 12
#define GPIO_SCLK 14
#define GPIO_CS 15
#define GPIO_BACK 10	//上升沿中断信号
#define GPIO_TEST 9
#define GPIO_TEST1 3
#define GPIO_TEST2 4
#define GPIO_TEST3 5
#define SENDER_HOST SPI2_HOST

//I2C Slave Address
#define DATA_LENGTH 512                  /*!< Data buffer length of test buffer */
#define RW_TEST_LENGTH 128               /*!< Data length for r/w test, [0,DATA_LENGTH] */
#define DELAY_TIME_BETWEEN_ITEMS_MS 1000 /*!< delay time between different test items */

#define I2C_MASTER_SCL_IO 2               /*!< gpio number for I2C master clock */
#define I2C_MASTER_SDA_IO 1               /*!< gpio number for I2C master data  */
#define I2C_MASTER_NUM I2C_NUMBER(CONFIG_I2C_MASTER_PORT_NUM) /*!< I2C port number for master dev */
#define I2C_MASTER_FREQ_HZ 100000        /*!< I2C master clock frequency */
#define I2C_MASTER_TX_BUF_DISABLE 0                           /*!< I2C master doesn't need buffer */
#define I2C_MASTER_RX_BUF_DISABLE 0                           /*!< I2C master doesn't need buffer */

/*For MAX14547*/
#define MAX14547_WRITE_ADDR 0xEE   /*!< slave address for write */
#define MAX14547_READ_ADDR  0xEF  /*!< slave address for read */
#define WRITE_BIT 0x0              /*!< I2C master write */
#define READ_BIT 0x1                /*!< I2C master read */
#define ACK_CHECK_EN 0x1                        /*!< I2C master will check ack from slave*/
#define ACK_CHECK_DIS 0x0                       /*!< I2C master will not check ack from slave */
#define ACK_VAL 0x0                             /*!< I2C ack value */
#define NACK_VAL 0x1                            /*!< I2C nack value */

#define LLV1_ADDR 0x05		//RMS output voltage control
#define OSI_LSB_ADDR 0x04
#define OIS_LSB 0x04

/*For TPL0102*/
#define TPL0102_ADDR 0xED
#define IVRA_REG 0x00
#define ACR_REG 0x10	


//WIFI及TCP参数
#define EXAMPLE_ESP_WIFI_SSID "HUAWEI-TEST"
#define EXAMPLE_ESP_WIFI_PASS "12345678"
char host_ip[] = "192.168.3.3";
int  port = 5001;

//SPI传输BUF尺寸定义
#define SPI_BUF_SIZE 38192

//I2C传输BUF尺寸定义
#define I2C_BUF_SIZE 3

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

//static char value[SPI_BUF_SIZE] = "12345678";
static char sendbuf[SPI_BUF_SIZE] = {0};
static char recvbuf[SPI_BUF_SIZE] = {0};

//ctrl signal
static char ctrlbuf[5] = {0};	//EWL_LSB, EWL_MSB, ACR_CONFIG, IVRA_CONFIG, CTRLCODE
static char EWL_LSB = {0};	//EWL is for I2C bus
static char EWL_MSB = {0};
static char ACR_CONFIG = {0};
static char IVRA_CONFIG = {0};
static char CTRLCODE = {0};		//控制信号标志位, 0-DATA, 1-EWL, 2-LED, 3-CMOS

//static QueueHandle_t rdySem;

static TaskHandle_t wifisend;
static TaskHandle_t spi;
//static TaskHandle_t i2c_master;

static void IRAM_ATTR gpio_handshake_isr_handler(void *arg) {

	static uint32_t lasthandshaketime_us;
	uint32_t currtime_us = esp_timer_get_time();
	uint32_t diff = currtime_us - lasthandshaketime_us;
	if (diff < 10) {
		return; //ignore everything <1us after an earlier irq
	}
	lasthandshaketime_us = currtime_us;

	xTaskNotifyGive(spi); 

	portYIELD_FROM_ISR();

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


static void spi_task(void *pvParameters){

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

	gpio_config_t io_conf_test1 = {
		.intr_type = GPIO_INTR_DISABLE,    
		.mode = GPIO_MODE_OUTPUT,
		.pull_down_en = 1,
		.pull_up_en = 0,
		.pin_bit_mask = (1 << GPIO_TEST1)
	};
	
	//Set up handshake line interrupt.
	gpio_config(&io_conf_test1);

	esp_err_t ret;
	spi_device_handle_t handle;

	//Configuration for the SPI bus
	spi_bus_config_t buscfg = { 
        .mosi_io_num = GPIO_MOSI, 
        .miso_io_num = GPIO_MISO, 
        .sclk_io_num = GPIO_SCLK, 
        .quadwp_io_num = -1, 
        .quadhd_io_num = -1,
		.max_transfer_sz = 81920
    };

	//Configuration for the SPI device on the other side of the bus
	spi_device_interface_config_t devcfg = { 
        .command_bits = 0, 
        .address_bits = 0, 
        .dummy_bits = 0, 
        .clock_speed_hz = 40000000, //30MHz时钟频率
		.input_delay_ns = 0,
        .duty_cycle_pos = 128,        //50% duty cycle
		.mode = 1, 
        .spics_io_num = GPIO_CS, 
        .cs_ena_posttrans = 3, //Keep the CS low 3 cycles after transaction, to stop slave from missing the last bit when CS has less propagation delay than CLK
		.queue_size = 9 
    };

	spi_transaction_t t;

	//xSemaphoreGiveFromISR(rdySem, &mustYield);  //要注意，这个中断处理程序触发的前提就是检测到handshake信号的上升沿
	//xTaskNotify(&gpio_set,value,eSetValueWithOverwrite); 

	//Initialize the SPI bus and add the device we want to send stuff to.
	ret = spi_bus_initialize(SENDER_HOST, &buscfg, SPI_DMA_CH_AUTO);
	assert(ret==ESP_OK);
	ret = spi_bus_add_device(SENDER_HOST, &devcfg, &handle);
	assert(ret==ESP_OK);

	while(1){

		//gpio_set_level(GPIO_TEST1,1);

		t.length = sizeof(sendbuf) * 8;  //可能是在这里控制传输总数据量来控制传输起止
		t.tx_buffer = sendbuf; 
		t.rx_buffer = recvbuf;
		
		//下面的逻辑是，在WiFi返回的控制信号有效时进入I2C传输，若检测到无效就开启SPI传输
		ulTaskNotifyTake(spi,portMAX_DELAY);  //检查前面给出的Notify信号量
		switch(ctrlbuf[5]){
			case '0':
				gpio_set_level(GPIO_TEST1,1);
				//ret = spi_device_transmit(handle, &t);  //这里准备把每包数据设为608*10*8，也就是八行数据一包
				break;
			case '1':
				gpio_set_level(GPIO_TEST2,1);
				//ret = i2c_MAX14547(I2C_MASTER_NUM);
			case '2':
				gpio_set_level(GPIO_TEST3,1);
				//ret = i2c_TPL0102(I2C_MASTER_NUM);
			case '3':
				//Reserved for COMS control
		}
		if (ret != ESP_OK) {
			ESP_LOGW(TAG, "%s: Pripherals Error:", esp_err_to_name(ret));
    	}
		//下面这个Notify是必选项，原因是控制指令的接收也需要WiFi来传输
		xTaskNotify(wifisend,1,eSetValueWithOverwrite); //然后再通过通知量把value的值传出去

	}
}

/**
 * initialize i2c bus
 * _______________________________________________________________________________________
 * | start | slave_addr + rd_bit + ack | register_addr + ack  | write 1 byte + ack | stop |
 * --------|---------------------------|----------------------|--------------------|------|
 * release i2c bus
 */
static esp_err_t i2c_MAX14547(i2c_port_t i2c_num)
{ 
    int ret;
	EWL_LSB = ctrlbuf[0]; 	//OIS_LSB
	EWL_MSB = ctrlbuf[1]; 	//LLV1
    i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (MAX14547_WRITE_ADDR << 1) | WRITE_BIT, ACK_CHECK_EN);	//发送从机地址+写标志信号
	i2c_master_write_byte(cmd, OSI_LSB_ADDR, ACK_CHECK_EN);	//发送寄存器地址,寄存器地址会自增
    i2c_master_write_byte(cmd, EWL_LSB, ACK_CHECK_EN);		//发送控制信号
	i2c_master_write_byte(cmd, EWL_MSB, ACK_CHECK_EN);		//发送控制信号
    i2c_master_stop(cmd);
    ret = i2c_master_cmd_begin(i2c_num, cmd, 1000 / portTICK_PERIOD_MS);
    i2c_cmd_link_delete(cmd);
    if (ret != ESP_OK) {
        return ret;
    }
}

/**
 * initialize i2c bus
 * _______________________________________________________________________________________
 * | start | slave_addr + rd_bit + ack | register_addr + ack  | write 1 byte + ack | stop |
 * --------|---------------------------|----------------------|--------------------|------|
 * release i2c bus
 * 
 * initialize i2c bus
 * _______________________________________________________________________________________
 * | start | slave_addr + rd_bit + ack | register_addr + ack  | write 1 byte + ack | stop |
 * --------|---------------------------|----------------------|--------------------|------|
 * release i2c bus
 */
static esp_err_t i2c_TPL0102(i2c_port_t i2c_num)
{ 
    int ret;
	ACR_CONFIG = ctrlbuf[2]; 	//ACR
    i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (TPL0102_ADDR << 1) | WRITE_BIT, ACK_CHECK_EN);	//发送从机地址+写标志信号
	i2c_master_write_byte(cmd, ACR_REG, ACK_CHECK_EN);	//发送寄存器地址,寄存器地址会自增
    i2c_master_write_byte(cmd, ACR_CONFIG, ACK_CHECK_EN);		//发送控制信号
    i2c_master_stop(cmd);
    ret = i2c_master_cmd_begin(i2c_num, cmd, 1000 / portTICK_PERIOD_MS);
    i2c_cmd_link_delete(cmd);
    if (ret != ESP_OK) {
        return ret;
    }

	//这里不确定寄存器地址写满以后会不会从头开始，因此分别进行两次传输
	IVRA_CONFIG = ctrlbuf[3]; 	//IVRA
	i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (TPL0102_ADDR << 1) | WRITE_BIT, ACK_CHECK_EN);	//发送从机地址+写标志信号
	i2c_master_write_byte(cmd, IVRA_REG, ACK_CHECK_EN);	//发送寄存器地址,寄存器地址会自增
    i2c_master_write_byte(cmd, IVRA_CONFIG, ACK_CHECK_EN);		//发送控制信号
    i2c_master_stop(cmd);
    ret = i2c_master_cmd_begin(i2c_num, cmd, 1000 / portTICK_PERIOD_MS);
    i2c_cmd_link_delete(cmd);
    if (ret != ESP_OK) {
        return ret;
    }
}

static esp_err_t i2c_master_init(void)
{
    int i2c_master_port = I2C_MASTER_NUM;
    i2c_config_t conf = {
        .mode = I2C_MODE_MASTER,
        .sda_io_num = I2C_MASTER_SDA_IO,
        .sda_pullup_en = GPIO_PULLUP_ENABLE,
        .scl_io_num = I2C_MASTER_SCL_IO,
        .scl_pullup_en = GPIO_PULLUP_ENABLE,
        .master.clk_speed = I2C_MASTER_FREQ_HZ,
        // .clk_flags = 0,          /*!< Optional, you can use I2C_SCLK_SRC_FLAG_* flags to choose i2c source clock here. */
    };
    esp_err_t err = i2c_param_config(i2c_master_port, &conf);
    if (err != ESP_OK) {
        return err;
    }
    return i2c_driver_install(i2c_master_port, conf.mode, I2C_MASTER_RX_BUF_DISABLE, I2C_MASTER_TX_BUF_DISABLE, 0);
}

static void wifisend_task(void *pvParameters){

	//在上升沿控制下的测试信号
	gpio_config_t io_conf_back = {
		.intr_type = GPIO_INTR_DISABLE,    
		.mode = GPIO_MODE_OUTPUT,
		.pull_down_en = 1,
		.pull_up_en = 0,
		.pin_bit_mask = (1 << GPIO_TEST)
	};
	
	//Set up handshake line interrupt.
	gpio_config(&io_conf_back);

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
		int sock = socket(addr_family, SOCK_STREAM, ip_protocol);
		if (sock < 0) {
			ESP_LOGE(TAG, "Unable to create socket: errno %d", errno);
		}
		//ESP_LOGI(TAG, "Socket created, connecting to %s:%d", host_ip, port);
		int err = connect(sock, (struct sockaddr*) &dest_addr,
				sizeof(struct sockaddr_in6));
		if (err != 0) {
			ESP_LOGE(TAG, "Socket unable to connect: errno %d", errno);
		}
		ESP_LOGI(TAG, "TCP Successfully connected");

		static uint32_t flag;
		static int len;
		while(1){

			flag =0;
			xTaskNotifyWait(0,1,&flag,portMAX_DELAY);
			if(flag){
				send(sock, recvbuf, strlen(recvbuf), 0);  //recvbuf应该就是接收数据存放的地址
				
				len = recv(sock, ctrlbuf, strlen(ctrlbuf), 0);	//每包数据完成传输后PC发给ESP32一个应答信号，这个信号也可以携带控制信息

				if(ctrlbuf == '2'){		//标志控制指令已经传来
					//gpio_set_level(GPIO_TEST,1);
					printf("ctrlbuf:%s\n",ctrlbuf);
					printf("len:%d\n",len);
				}
				else{	//ack信号默认为1，因此else的唯一情况就是len=1
					//gpio_set_level(GPIO_TEST,0);
					printf("ctrlbuf not 2:%c",ctrlbuf);
					printf("len:%d\n",len);
				}
			}
			
		}
		vTaskDelete(NULL);
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

	//配置WiFi低功耗模式(Light-Sleep)
	#if CONFIG_PM_ENABLE
    	// Configure dynamic frequency scaling:
    	// maximum and minimum frequencies are set in sdkconfig,
    	// automatic light sleep is enabled if tickless idle support is enabled.
    	esp_pm_config_esp32s3_t pm_config = {
            .max_freq_mhz = 160,
            .min_freq_mhz = 10,
	#if CONFIG_FREERTOS_USE_TICKLESS_IDLE
            .light_sleep_enable = false
	#endif
    	};
    	ESP_ERROR_CHECK( esp_pm_configure(&pm_config) );
	#endif // CONFIG_PM_ENABLE

	xTaskCreatePinnedToCore(spi_task, "spi_task", 81920, NULL, 1, &spi,0);

	xTaskCreatePinnedToCore(wifisend_task, "wifisend_task", 81920, NULL, 1, &wifisend,1);
	//解决assert failed: xQueueGiveFromISR queue.c:1224 (pxQueue)问题的方法是修改任务句柄&gpio_set和任务优先级


}
