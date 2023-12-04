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
#include "esp32s3/rom/ets_sys.h"
#include "driver/i2c.h"

#define GPIO_HANDSHAKE 2
#define GPIO_MOSI 13
#define GPIO_MISO 12
#define GPIO_SCLK 14
#define GPIO_CS 15

//CMOS控制信号
#define GPIO_BB_MOSI 35
#define GPIO_BB_MISO 36
#define GPIO_BB_SCLK 37
#define GPIO_BB_CS 38

#define GPIO_BACK 10	//上升沿中断信号
#define GPIO_TEST 9
#define GPIO_TEST1 3
#define GPIO_TEST2 4
#define GPIO_TEST3 5
#define GPIO_ENT1 6
#define GPIO_STATUS_LED 7
#define SENDER_HOST SPI2_HOST
#define CMOSCTRL_HOST SPI3_HOST

#define DONE 1
#define DISABLE_PLL

//I2C Slave Address
#define DATA_LENGTH 512                  /*!< Data buffer length of test buffer */
#define RW_TEST_LENGTH 128               /*!< Data length for r/w test, [0,DATA_LENGTH] */
#define DELAY_TIME_BETWEEN_ITEMS_MS 1000 /*!< delay time between different test items */

#define I2C_MASTER_SCL_IO 2               /*!< gpio number for I2C master clock */
#define I2C_MASTER_SDA_IO 1               /*!< gpio number for I2C master data  */
#define I2C_MASTER_NUM 1 /*!< I2C port number for master dev */ //这写成1不知道对不对
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
#define SPI_BB_BUF_SIZE 4  //CMOS控制信号的传输位宽


/* FreeRTOS event group to signal when we are connected*/
static EventGroupHandle_t s_wifi_event_group;
/* The event group allows multiple bits for each event, but we only care about two events:
 * - we are connected to the AP with an IP
 * - we failed to connect after the maximum amount of retries */
#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT BIT1

//static char cmos_sendbuf[SPI_BB_BUF_SIZE] = {0};
//static char cmos_recvbuf[SPI_BB_BUF_SIZE] = {0};
static uint32_t cmos_sendbuf = 0;
static uint32_t cmos_recvbuf = 0;

/*CMOS SPI控制参数传输函数*/
static esp_err_t spi_BB_Write(uint16_t address, uint16_t value){
//package fomat(MSB->LSB): 6bits dummy(zero) + 9bits address + 1bit w/r + 16bits value
	uint32_t packagedata;	//reformatted data
	packagedata = address;	//16bits -> 32bits
	packagedata = (((packagedata << 1) + 1) << 16) + value;	

	spi_transaction_t t;
	cmos_sendbuf = packagedata;	//push packagedata into send buffer
	//t.length = sizeof(cmos_sendbuf) * 8; 
	t.length = sizeof(cmos_sendbuf);
	t.tx_buffer = &cmos_sendbuf;
	t.rx_buffer = &cmos_recvbuf;

	esp_err_t ret;
	ret = spi_device_transmit(handle_cmos, &t);

	return ret;
}

static void spi_task(void *pvParameters){

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
        .clock_speed_hz = 20000000, //40MHz时钟频率
		.input_delay_ns = 0,
        .duty_cycle_pos = 128,        //50% duty cycle
		.mode = 1, 
        .spics_io_num = GPIO_CS, 
        .cs_ena_posttrans = 3, //Keep the CS low 3 cycles after transaction, to stop slave from missing the last bit when CS has less propagation delay than CLK
		.queue_size = 9 
    };

	spi_transaction_t t;

	//Initialize the SPI bus and add the device we want to send stuff to.
	ret = spi_bus_initialize(SENDER_HOST, &buscfg, SPI_DMA_CH_AUTO);
	assert(ret==ESP_OK);
	ret = spi_bus_add_device(SENDER_HOST, &devcfg, &handle);
	assert(ret==ESP_OK);

	//注册发送CMOS控制指令的SPI 通道
	static esp_err_t ret_cmos;
	//Initialize the SPI bus and add the device we want to send stuff to.
	ret_cmos = spi_bus_initialize(CMOSCTRL_HOST, &buscfg, SPI_DMA_CH_AUTO);
	assert(ret_cmos==ESP_OK);
	ret_cmos = spi_bus_add_device(CMOSCTRL_HOST, &devcfg, &handle_cmos);	//注意这里的时钟频率还是40MHz
	assert(ret_cmos==ESP_OK);

	while(1){

		spi_BB_Write(0x32A,0x924D);

	}
}

//Main application
void app_main(void) {

	xTaskCreatePinnedToCore(spi_task, "spi_task", 81920, NULL, 1, &spi,0);
	
}
